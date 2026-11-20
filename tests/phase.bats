#!/usr/bin/env bats

load helpers

setup() { make_repo; stamp; }

teardown() {
  # Never leave a watchdog sleeping behind a test.
  local pid
  pid="$(jq -r '.watchdog_pid // empty' "$CHAOS_DIR/runs/.active" 2>/dev/null || true)"
  [[ -n "$pid" ]] && kill -- "-$pid" 2>/dev/null || true
}

p() { "$SCRIPTS/phase" "$@"; }
rec() { cat "$CHAOS_DIR"/runs/*/record.json; }

@test "a held run walks the phases and cleans up" {
  run p start demo-kill
  [ "$status" -eq 0 ]
  p up; p guard; p baseline; p to inject; p fault apply
  [ -e "$REPO/state/fault-demo-kill" ]
  p to observe
  run p check
  [ "$status" -eq 1 ]
  p fault revert
  run p check
  [ "$status" -eq 0 ]
  p to cleanup
  p end held
  [ ! -e "$CHAOS_DIR/runs/.active" ]
  [ "$(rec | jq -r .outcome)" = held ]
  grep -q down "$REPO/state/sandbox.log"
}

@test "an unreviewed hypothesis cannot start a run" {
  echo "# edit" >> "$CHAOS_DIR/hypotheses/demo-kill/fault"
  run p start demo-kill
  [ "$status" -ne 0 ]
  [[ "$output" == *"fault or check changed since review"* ]]
  [ ! -e "$CHAOS_DIR/runs/.active" ]
}

@test "an unreviewed binding cannot start a run" {
  echo "# edit" >> "$CHAOS_DIR/sandbox/guard"
  run p start demo-kill
  [ "$status" -ne 0 ]
  [[ "$output" == *"changed since review"* ]]
}

@test "phases cannot go backwards" {
  p start demo-kill; p guard; p baseline; p to inject; p to observe
  run p to inject
  [ "$status" -ne 0 ]
  [[ "$output" == *"only move forward"* ]]
}

@test "inject needs the guard to have passed" {
  p start demo-kill
  run p to inject
  [ "$status" -ne 0 ]
  [[ "$output" == *"phase guard first"* ]]
}

@test "a failing guard blocks the fault" {
  p start demo-kill; p guard; p baseline; p to inject
  printf '#!/usr/bin/env bash\nexit 1\n' > "$CHAOS_DIR/sandbox/guard"
  run p fault apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"guard failed"* ]]
  [ ! -e "$REPO/state/fault-demo-kill" ]
}

@test "fault apply is refused outside inject and triage" {
  p start demo-kill; p guard; p baseline; p to inject; p to observe
  run p fault apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"not allowed in phase 'observe'"* ]]
}

@test "triage may re-apply the fault exactly once" {
  p start demo-kill; p guard; p baseline; p to inject; p fault apply; p to observe; p fault revert; p to triage; p reset
  run p fault apply
  [ "$status" -eq 0 ]
  p fault revert
  run p fault apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"only once"* ]]
}

@test "existing targets need confirmation before inject" {
  sed -i 's/^kind:.*/kind: existing/' "$CHAOS_DIR/target.md"
  stamp
  p start demo-kill; p guard
  run p to inject
  [ "$status" -ne 0 ]
  [[ "$output" == *"phase confirm first"* ]]
  p confirm; p baseline
  run p to inject
  [ "$status" -eq 0 ]
}

@test "abort reverts an active fault and records the failed phase" {
  p start demo-kill; p guard; p baseline; p to inject; p fault apply
  run p abort "agent crashed"
  [ "$status" -eq 0 ]
  [ ! -e "$REPO/state/fault-demo-kill" ]
  [ "$(rec | jq -r .outcome)" = aborted ]
  [ "$(rec | jq -r .failed_phase)" = inject ]
  [ "$(rec | jq -r .note)" = "agent crashed" ]
}

@test "a second run cannot start while one is active" {
  p start demo-kill
  run p start demo-kill
  [ "$status" -ne 0 ]
  [[ "$output" == *"still active"* ]]
}

@test "the watchdog reverts the fault at duration expiry" {
  sed -i 's/^duration:.*/duration: 12s/; s/^check_timeout:.*/check_timeout: 1s/' "$CHAOS_DIR/hypotheses/demo-kill/hypothesis.md"; stamp
  p start demo-kill; p guard; p baseline; p to inject; p fault apply
  [ -e "$REPO/state/fault-demo-kill" ]
  for _ in $(seq 1 32); do [ -e "$REPO/state/fault-demo-kill" ] || break; sleep 0.5; done
  [ ! -e "$REPO/state/fault-demo-kill" ]
  grep -q reverted "$REPO/state/revert-demo-kill.log"
  [ "$(jq -r .fault_active "$CHAOS_DIR/runs/.active")" = false ]
  rec | jq -e '.phases[] | select(.phase | startswith("fault reverted by watchdog"))'
}

@test "a manual revert stops the watchdog" {
  sed -i 's/^duration:.*/duration: 12s/; s/^check_timeout:.*/check_timeout: 1s/' "$CHAOS_DIR/hypotheses/demo-kill/hypothesis.md"; stamp
  p start demo-kill; p guard; p baseline; p to inject; p fault apply; p fault revert
  sleep 13
  [ "$(grep -c reverted "$REPO/state/revert-demo-kill.log")" -eq 1 ]
}

@test "fault apply refuses when the fault is already active on the target" {
  p start demo-kill; p guard; p baseline; p to inject
  touch "$REPO/state/fault-demo-kill"   # left over from an earlier run
  run p fault apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"already active on the target"* ]]
  [ "$(jq -r .fault_active "$CHAOS_DIR/runs/.active")" = false ]
}
