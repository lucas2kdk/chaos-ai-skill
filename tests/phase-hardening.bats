#!/usr/bin/env bats
# Baseline, fault effect, check timing, recovery, reset, provenance and confirmations.

load helpers

setup() { make_repo; stamp; }

teardown() {
  local pid
  pid="$(jq -r '.watchdog_pid // empty' "$CHAOS_DIR/runs/.active" 2>/dev/null || true)"
  [[ -n "$pid" ]] && kill -- "-$pid" 2>/dev/null || true
}

p() { "$SCRIPTS/phase" "$@"; }
rec() { cat "$CHAOS_DIR"/runs/*/record.json; }
hyp_set() { sed -i "s/^$1:.*/$1: $2/" "$CHAOS_DIR/hypotheses/demo-kill/hypothesis.md"; }
hyp_add() { sed -i "s/^duration:.*/&\n$1: $2/" "$CHAOS_DIR/hypotheses/demo-kill/hypothesis.md"; }
fault_body() { printf '#!/usr/bin/env bash\n%s\n' "$1" > "$CHAOS_DIR/hypotheses/demo-kill/fault"; }

# 3.1 baseline

@test "inject needs a passed baseline" {
  p start demo-kill; p guard
  run p to inject
  [ "$status" -ne 0 ]
  [[ "$output" == *"run phase baseline first"* ]]
  run p baseline
  [ "$status" -eq 0 ]
  [[ "$output" == *"baseline holds"* ]]
  run p to inject
  [ "$status" -eq 0 ]
  [ "$(rec | jq -r .baseline)" = pass ]
}

@test "an already-violated target fails the baseline and cannot inject" {
  touch "$REPO/state/fault-demo-kill"   # target unhealthy before any fault
  # make status report inactive anyway, so only the check sees the problem
  sed -i 's/if \[\[ -e "$m" \]\]; then echo active; else echo inactive; fi/echo inactive/' "$CHAOS_DIR/hypotheses/demo-kill/fault"
  stamp
  p start demo-kill; p guard
  run p baseline
  [ "$status" -eq 1 ]
  [[ "$output" == *"BASELINE VIOLATED"* ]]
  run p to inject
  [ "$status" -ne 0 ]
  [ "$(rec | jq -r .baseline)" = fail ]
}

# 3.2 fault effect

@test "a fault that never becomes active is reverted and exits 3" {
  fault_body 'case "$1" in apply) : ;; revert) echo reverted >> "'"$REPO"'/state/noop-revert.log" ;; status) echo inactive ;; esac'
  stamp
  p start demo-kill; p guard; p baseline; p to inject
  run p fault apply
  [ "$status" -eq 3 ]
  [[ "$output" == *"FAULT DID NOT TAKE EFFECT"* ]]
  grep -q reverted "$REPO/state/noop-revert.log"
  [ "$(jq -r .fault_active "$CHAOS_DIR/runs/.active")" = false ]
  rec | jq -e '.phases[] | select(.phase == "fault applied" and .status_after == "inactive")'
}

@test "a working fault prints a confirmation" {
  p start demo-kill; p guard; p baseline; p to inject
  run p fault apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"fault active (confirmed)"* ]]
  rec | jq -e '.phases[] | select(.phase == "fault applied" and .status_after == "active")'
}

@test "a one-off fault is not asserted and says so" {
  fault_body 'case "$1" in apply) touch "'"$REPO"'/state/killed" ;; revert) : ;; status) echo inactive ;; esac'
  hyp_add one_off true
  stamp
  p start demo-kill; p guard; p baseline; p to inject
  run p fault apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"one-off fault applied (effect not asserted)"* ]]
  [ -e "$REPO/state/killed" ]
  # the watchdog keeps running to poll abort checks
  [ "$(jq -r .watchdog_pid "$CHAOS_DIR/runs/.active")" != null ]
}

# 3.3 check timing

@test "phase check waits until wait has passed since the fault was applied" {
  hyp_set wait 3s; stamp
  p start demo-kill; p guard; p baseline; p to inject; p fault apply; p to observe
  start=$(date +%s)
  run p check
  [ "$status" -eq 1 ]
  (( $(date +%s) - start >= 2 ))
  rec | jq -e '.phases[] | select(.phase == "check 2 exit 1" and (.summary | startswith("VIOLATED")))'
}

@test "a check that runs past check_timeout counts as violated" {
  printf '#!/usr/bin/env bash\n[[ -e "%s/state/hang" ]] && sleep 30\necho ok\n' "$REPO" > "$CHAOS_DIR/hypotheses/demo-kill/check"
  hyp_set check_timeout 2s; stamp
  p start demo-kill; p guard; p baseline; p to inject; p fault apply; p to observe
  touch "$REPO/state/hang"
  run p check
  [ "$status" -eq 124 ]
  [[ "$output" == *"VIOLATED: check timed out after 2s"* ]]
}

# 3.4 recover

@test "recover records the recovery time when the target heals" {
  p start demo-kill; p guard; p baseline; p to inject; p fault apply; p to observe
  p fault revert
  run p recover
  [ "$status" -eq 0 ]
  [[ "$output" == *"recovered after"* ]]
  [ "$(rec | jq -r .recovered)" = true ]
  [ "$(rec | jq -r .recovery_seconds)" -le 1 ]
}

@test "recover reports a target that stays broken" {
  # revert does not remove the marker: the bug outlives the fault
  sed -i 's/  revert) rm -f "$m"; /  revert) /' "$CHAOS_DIR/hypotheses/demo-kill/fault"
  sed -i 's/if \[\[ -e "$m" \]\]; then echo active; else echo inactive; fi/if [[ -e "$m.on" ]]; then echo active; else echo inactive; fi/; s/  apply) touch "$m" ;;/  apply) touch "$m" "$m.on" ;;/; s/  revert) /  revert) rm -f "$m.on"; /' "$CHAOS_DIR/hypotheses/demo-kill/fault"
  hyp_add recovers_within 3s; stamp
  p start demo-kill; p guard; p baseline; p to inject; p fault apply; p to observe
  p fault revert
  run p recover
  [ "$status" -eq 1 ]
  [[ "$output" == *"NOT RECOVERED"* ]]
  [ "$(rec | jq -r .recovered)" = false ]
}

@test "recover refuses while the fault is active" {
  p start demo-kill; p guard; p baseline; p to inject; p fault apply; p to observe
  run p recover
  [ "$status" -ne 0 ]
  [[ "$output" == *"revert the fault first"* ]]
}

# 3.5 reset and note

@test "reset is refused outside triage" {
  p start demo-kill; p guard; p baseline; p to inject; p fault apply; p to observe; p fault revert
  run p reset
  [ "$status" -ne 0 ]
  [[ "$output" == *"allowed in: triage"* ]]
}

@test "reset runs down, up, guard and baseline once, then refuses" {
  p start demo-kill; p up; p guard; p baseline; p to inject; p fault apply; p to observe; p fault revert; p to triage
  : > "$REPO/state/sandbox.log"
  run p reset
  [ "$status" -eq 0 ]
  [[ "$output" == *"the repeat may run"* ]]
  [ "$(tr '\n' ' ' < "$REPO/state/sandbox.log")" = "down up guard " ]
  p fault apply; p fault revert
  [ "$(rec | jq -r .reproduction)" = repeated ]
  run p reset
  [ "$status" -ne 0 ]
  [[ "$output" == *"only once"* ]]
}

@test "triage cannot repeat the fault without a fresh start" {
  p start demo-kill; p guard; p baseline; p to inject; p fault apply; p to observe; p fault revert; p to triage
  run p fault apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"repeats from a fresh start"* ]]
}

@test "reset is refused for an existing target; its baseline decides instead" {
  sed -i 's/^kind:.*/kind: existing/' "$CHAOS_DIR/target.md"; stamp
  p start demo-kill; p confirm; p guard; p baseline; p to inject; p fault apply; p to observe; p fault revert; p to triage
  run p reset
  [ "$status" -ne 0 ]
  [[ "$output" == *"reset is for sandbox targets"* ]]
  run p baseline
  [ "$status" -eq 0 ]
  run p fault apply
  [ "$status" -eq 0 ]
}

@test "an existing target that has not recovered skips the repeat" {
  sed -i 's/^kind:.*/kind: existing/' "$CHAOS_DIR/target.md"; stamp
  p start demo-kill; p confirm; p guard; p baseline; p to inject; p fault apply; p to observe; p fault revert; p to triage
  touch "$REPO/state/fault-demo-kill.sick"
  sed -i 's/^if \[\[ -e "\(.*\)" \]\]; then echo "VIOLATED marker present"/if [[ -e "\1" || -e "\1.sick" ]]; then echo "VIOLATED marker present"/' "$CHAOS_DIR/hypotheses/demo-kill/check"
  run p baseline
  [ "$status" -eq 1 ]
  [[ "$output" == *"not independently reproduced"* ]]
  [ "$(rec | jq -r .reproduction)" = skipped ]
  p note "not independently reproduced"
  [ "$(rec | jq -r '.notes[0]')" = "not independently reproduced" ]
}

# 3.6 provenance

@test "the record holds provenance" {
  git -C "$REPO" init -q
  git -C "$REPO" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  sed -i 's/^must_not_affect:.*/&\nfidelity: public base image/' "$CHAOS_DIR/target.md"; stamp
  p start demo-kill
  r="$(rec)"
  [ "$(jq -r .provenance.commit <<<"$r")" = "$(git -C "$REPO" rev-parse HEAD)" ]
  [ "$(jq -r .provenance.dirty <<<"$r")" = true ]
  [ "$(jq -r .provenance.fidelity <<<"$r")" = "public base image" ]
  [ "$(jq -r .provenance.binding_hash <<<"$r")" = "$(awk '$1=="binding:"{print $2}' "$CHAOS_DIR/.review")" ]
  [ "$(jq -r .provenance.hypothesis_hash <<<"$r")" = "$(awk '$1=="hypothesis/demo-kill:"{print $2}' "$CHAOS_DIR/.review")" ]
}

@test "provenance is null outside git, and guard output and revert status are recorded" {
  p start demo-kill; p guard; p baseline; p to inject; p fault apply; p fault revert
  r="$(rec)"
  [ "$(jq -r .provenance.commit <<<"$r")" = null ]
  jq -e '.phases[] | select(.phase == "guard passed" and has("output"))' <<<"$r"
  jq -e '.phases[] | select(.phase == "fault reverted" and .status_after == "inactive")' <<<"$r"
}

# 3.7 confirmations and show

@test "end confirms cleanup" {
  p start demo-kill; p guard; p baseline; p to inject; p fault apply
  run p abort "test"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cleanup confirmed: fault inactive"* ]]
}

@test "end says loudly when cleanup cannot be confirmed" {
  p start demo-kill; p guard; p baseline; p to inject; p fault apply
  sed -i 's/  revert) rm -f "$m"; /  revert) /' "$CHAOS_DIR/hypotheses/demo-kill/fault"
  run p abort "test"
  [ "$status" -eq 1 ]
  [[ "$output" == *"CLEANUP NOT CONFIRMED"* ]]
}

@test "show includes the watchdog deadline while a fault is active" {
  p start demo-kill; p guard; p baseline; p to inject
  [ "$(p show | jq -r .watchdog_deadline)" = null ]
  p fault apply
  d="$(p show | jq -r .watchdog_deadline)"
  [[ "$d" =~ ^20[0-9]{2}-[0-9]{2}-[0-9]{2}T ]]
}

@test "the record's provenance carries source and control settings" {
  sed -i 's/^duration:.*/&\nsource: INC-77\ncontrol: false/' "$CHAOS_DIR/hypotheses/demo-kill/hypothesis.md"; stamp
  p start demo-kill
  [ "$(rec | jq -r .provenance.source)" = INC-77 ]
  [ "$(rec | jq -r .provenance.control)" = false ]
  [ "$(rec | jq -r .provenance.tolerance_percent)" = null ]
}

@test "phase start --auto records mode auto" {
  p start --auto demo-kill
  [ "$(rec | jq -r .mode)" = auto ]
  [ "$(jq -r .mode "$CHAOS_DIR/runs/.active")" = auto ]
}
