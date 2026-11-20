#!/usr/bin/env bats
# Abort checks polled by the watchdog while a fault is active.

load helpers

setup() {
  make_repo
  sed -i 's/^duration:.*/&\nabort_interval: 1s/' "$CHAOS_DIR/hypotheses/demo-kill/hypothesis.md"
}

teardown() {
  local pid
  pid="$(jq -r '.watchdog_pid // empty' "$CHAOS_DIR/runs/.active" 2>/dev/null || true)"
  [[ -n "$pid" ]] && kill -- "-$pid" 2>/dev/null || true
}

p() { "$SCRIPTS/phase" "$@"; }
rec() { cat "$CHAOS_DIR"/runs/*/record.json; }
# abort_script <path> <body>: an executable abort check
abort_script() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$1"; chmod +x "$1"; }
# wait_for <jq filter on .active>: poll up to 8s
wait_aborted() {
  for _ in $(seq 1 32); do
    [[ "$(jq -r '.aborted_by // empty' "$CHAOS_DIR/runs/.active")" != "" ]] && return 0
    sleep 0.25
  done
  return 1
}
start_fault() { stamp; p start demo-kill >/dev/null; p guard >/dev/null; p baseline >/dev/null; p to inject >/dev/null; p fault apply >/dev/null; }

@test "a failing target abort check reverts the fault and records why" {
  abort_script "$CHAOS_DIR/sandbox/abort" "if [[ -e '$REPO/state/stop' ]]; then echo 'error rate 40%'; exit 1; fi"
  start_fault
  [ -e "$REPO/state/fault-demo-kill" ]
  touch "$REPO/state/stop"
  wait_aborted
  [ ! -e "$REPO/state/fault-demo-kill" ]
  [ "$(jq -r .aborted_by "$CHAOS_DIR/runs/.active")" = "target abort check" ]
  [ "$(jq -r .fault_active "$CHAOS_DIR/runs/.active")" = false ]
  [ "$(rec | jq -r .abort_output)" = "error rate 40%" ]
  rec | jq -e '.phases[] | select(.phase == "experiment stopped by target abort check: error rate 40%")'
}

@test "a failing hypothesis abort check stops the experiment" {
  abort_script "$CHAOS_DIR/hypotheses/demo-kill/abort" "[[ -e '$REPO/state/stop' ]] && { echo 'restarts: 3'; exit 1; }; exit 0"
  start_fault
  touch "$REPO/state/stop"
  wait_aborted
  [ "$(jq -r .aborted_by "$CHAOS_DIR/runs/.active")" = "hypothesis abort check" ]
}

@test "a hanging abort check counts as a stop" {
  abort_script "$CHAOS_DIR/hypotheses/demo-kill/abort" "[[ -e '$REPO/state/stop' ]] && sleep 30; exit 0"
  start_fault
  touch "$REPO/state/stop"
  wait_aborted
  [ "$(jq -r .abort_output "$CHAOS_DIR/runs/.active")" = "abort check timed out after 1s" ]
}

@test "after an abort, check, recover and fault apply are refused and abort records the reason" {
  abort_script "$CHAOS_DIR/hypotheses/demo-kill/abort" "[[ -e '$REPO/state/stop' ]] && { echo 'queue depth 9000'; exit 1; }; exit 0"
  start_fault
  p to observe >/dev/null
  touch "$REPO/state/stop"
  wait_aborted
  for c in check recover "fault apply"; do
    run p $c
    [ "$status" -ne 0 ]
    [[ "$output" == *"stopped by the hypothesis abort check (queue depth 9000); end the run with: phase abort"* ]]
  done
  run p abort
  [ "$status" -eq 0 ]
  [ "$(rec | jq -r .outcome)" = aborted ]
  [ "$(rec | jq -r .note)" = "stopped by the hypothesis abort check: queue depth 9000" ]
}

@test "abort checks keep running for a one-off fault" {
  sed -i 's/^duration:.*/&\none_off: true/' "$CHAOS_DIR/hypotheses/demo-kill/hypothesis.md"
  abort_script "$CHAOS_DIR/hypotheses/demo-kill/abort" "[[ -e '$REPO/state/stop' ]] && { echo 'still down'; exit 1; }; exit 0"
  start_fault
  [ "$(jq -r .fault_active "$CHAOS_DIR/runs/.active")" = false ]
  [ "$(jq -r .watchdog_pid "$CHAOS_DIR/runs/.active")" != null ]
  touch "$REPO/state/stop"
  wait_aborted
  [ "$(jq -r .aborted_by "$CHAOS_DIR/runs/.active")" = "hypothesis abort check" ]
}

@test "a passing abort check leaves the experiment alone" {
  abort_script "$CHAOS_DIR/sandbox/abort" "exit 0"
  start_fault
  sleep 3
  [ "$(jq -r '.aborted_by // "none"' "$CHAOS_DIR/runs/.active")" = none ]
  [ "$(jq -r .fault_active "$CHAOS_DIR/runs/.active")" = true ]
}
