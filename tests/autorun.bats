#!/usr/bin/env bats
# Unattended runs: autorun drives phase without an agent and reports changes in outcome.

load helpers

setup() {
  make_repo
  make_hypothesis steady-one
  # steady-one's check ignores its fault: it always holds
  printf '#!/usr/bin/env bash\necho ok\n' > "$CHAOS_DIR/hypotheses/steady-one/check"
  stamp
}

teardown() {
  local pid
  pid="$(jq -r '.watchdog_pid // empty' "$CHAOS_DIR/runs/.active" 2>/dev/null || true)"
  [[ -n "$pid" ]] && kill -- "-$pid" 2>/dev/null || true
}

a() { "$SCRIPTS/autorun" "$@"; }
latest_summary() { ls -1 "$CHAOS_DIR"/runs/autorun-*.json | sort | tail -n1; }
change_of() { jq -r --arg h "$1" '.hypotheses[] | select(.hypothesis == $h) | .change' "$(latest_summary)"; }

@test "first run: a new violation exits 1, the summary lists both, no finding is filed" {
  run a --all
  [ "$status" -eq 1 ]
  [[ "$output" == *"demo-kill: violated (new)"* ]]
  [[ "$output" == *"needs triage: /chaos:run demo-kill"* ]]
  [[ "$output" == *"steady-one: held (new)"* ]]
  [ "$(change_of demo-kill)" = new ]
  [ "$(jq -r '.exit' "$(latest_summary)")" = 1 ]
  [ ! -e "$CHAOS_DIR/findings" ]
  r="$(jq -r '.hypotheses[] | select(.hypothesis == "demo-kill") | .run' "$(latest_summary)")"
  [ "$(jq -r .mode "$CHAOS_DIR/runs/$r/record.json")" = auto ]
  [ "$(jq -r .needs_triage "$CHAOS_DIR/runs/$r/record.json")" = true ]
  [ "$(jq -r '.hypotheses[] | select(.hypothesis == "steady-one") | .recovered' "$(latest_summary)")" = true ]
  [ ! -e "$REPO/state/fault-demo-kill" ]
  [ ! -e "$CHAOS_DIR/runs/.active" ]
}

@test "second run with the same results is unchanged and exits 0" {
  a --all || true
  sleep 1
  run a --all
  [ "$status" -eq 0 ]
  [ "$(change_of demo-kill)" = unchanged ]
  [ "$(change_of steady-one)" = unchanged ]
}

@test "held then violated is a regression; violated then held is fixed" {
  run a steady-one
  [ "$status" -eq 0 ]
  printf '#!/usr/bin/env bash\n[[ -e "%s/state/fault-steady-one" ]] && { echo VIOLATED; exit 1; }\necho ok\n' "$REPO" > "$CHAOS_DIR/hypotheses/steady-one/check"
  stamp; sleep 1
  run a steady-one
  [ "$status" -eq 1 ]
  [ "$(change_of steady-one)" = regression ]
  printf '#!/usr/bin/env bash\necho ok\n' > "$CHAOS_DIR/hypotheses/steady-one/check"
  stamp; sleep 1
  run a steady-one
  [ "$status" -eq 0 ]
  [ "$(change_of steady-one)" = fixed ]
}

@test "unreviewed hypotheses are skipped with the reason; the others run" {
  echo "# edit" >> "$CHAOS_DIR/hypotheses/demo-kill/fault"
  run a --all
  [[ "$output" == *"demo-kill: skipped (hypothesis.md, fault or check changed since review"* ]]
  [ "$(change_of demo-kill)" = skipped ]
  [ "$(change_of steady-one)" = new ]
  [ "$status" -eq 0 ]
}

@test "an existing target is refused before anything runs" {
  sed -i 's/^kind:.*/kind: existing/' "$CHAOS_DIR/target.md"; stamp
  run a --all
  [ "$status" -eq 2 ]
  [[ "$output" == *"sandbox targets only"* ]]
  [ -z "$(ls "$CHAOS_DIR/runs" 2>/dev/null | grep -v '^\.' || true)" ]
}

@test "an active run or another autorun blocks it" {
  "$SCRIPTS/phase" start demo-kill >/dev/null
  run a --all
  [ "$status" -eq 2 ]
  [[ "$output" == *"is active; not touching the target"* ]]
  "$SCRIPTS/phase" abort >/dev/null
  mkdir "$CHAOS_DIR/runs/.autorun.lock"
  run a --all
  [ "$status" -eq 2 ]
  [[ "$output" == *"another autorun"* ]]
  rmdir "$CHAOS_DIR/runs/.autorun.lock"
}

@test "an unconfirmed cleanup exits 2 and stops the batch" {
  sed -i 's/  revert) rm -f "$m"; /  revert) /' "$CHAOS_DIR/hypotheses/demo-kill/fault"
  sed -i 's/^check_timeout:.*/&\nrecovers_within: 2s/' "$CHAOS_DIR/hypotheses/demo-kill/hypothesis.md"
  stamp
  run a demo-kill steady-one
  [ "$status" -eq 2 ]
  [ "$(change_of demo-kill)" = incomplete ]
  [ "$(change_of steady-one)" = skipped ]
  [[ "$(jq -r '.hypotheses[] | select(.hypothesis == "steady-one") | .note' "$(latest_summary)")" == *"unconfirmed cleanup"* ]]
}

@test "a baseline that is already violated aborts that hypothesis as incomplete" {
  touch "$REPO/state/fault-demo-kill"
  sed -i 's/if \[\[ -e "$m" \]\]; then echo active; else echo inactive; fi/echo inactive/' "$CHAOS_DIR/hypotheses/demo-kill/fault"
  stamp
  run a demo-kill
  [ "$status" -eq 2 ]
  [ "$(change_of demo-kill)" = incomplete ]
  r="$(jq -r '.hypotheses[0].run' "$(latest_summary)")"
  [ "$(jq -r .note "$CHAOS_DIR/runs/$r/record.json")" = "baseline violated" ]
}
