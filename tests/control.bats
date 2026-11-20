#!/usr/bin/env bats
# Control-group hypotheses: both groups measured at the same time, compared against a tolerance.

load helpers

setup() {
  make_repo
  local d="$CHAOS_DIR/hypotheses/demo-kill"
  sed -i 's/^duration:.*/&\ncontrol: true\ntolerance: 10%/' "$d/hypothesis.md"
  # each group's value comes from a file; the fault drops the experimental group to state/ev-fault
  cat > "$d/check" <<EOF
#!/usr/bin/env bash
case "\$1" in
  control)    f="$REPO/state/cv" ;;
  experiment) f="$REPO/state/ev"; [[ -e "$REPO/state/fault-demo-kill" ]] && f="$REPO/state/ev-fault" ;;
  *) echo "usage: check control|experiment" >&2; exit 2 ;;
esac
[[ -e "\$f.fail" ]] && { echo "probe failed"; exit 1; }
echo "measured \$1"
echo "value: \$(cat "\$f")"
EOF
  echo 100 > "$REPO/state/cv"; echo 98 > "$REPO/state/ev"; echo 70 > "$REPO/state/ev-fault"
  stamp
}

teardown() {
  local pid
  pid="$(jq -r '.watchdog_pid // empty' "$CHAOS_DIR/runs/.active" 2>/dev/null || true)"
  [[ -n "$pid" ]] && kill -- "-$pid" 2>/dev/null || true
}

p() { "$SCRIPTS/phase" "$@"; }
rec() { cat "$CHAOS_DIR"/runs/*/record.json; }
to_observe() { p start demo-kill >/dev/null; p guard >/dev/null; p baseline >/dev/null; p to inject >/dev/null; p fault apply >/dev/null; p to observe >/dev/null; }

@test "groups within tolerance pass, and both values are recorded" {
  echo 95 > "$REPO/state/ev-fault"
  to_observe
  run p check
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok: experiment 95 vs control 100 differs by 5.0% (tolerance 10%)"* ]]
  rec | jq -e '.phases[] | select(.control == 100 and .experiment == 95 and .diff_percent == 5)'
}

@test "groups outside tolerance are a violation" {
  to_observe
  run p check
  [ "$status" -eq 1 ]
  [[ "$output" == *"VIOLATED: experiment 70 vs control 100 differs by 30.0% (tolerance 10%)"* ]]
  [[ "$output" == *"== control (exit 0)"* && "$output" == *"== experiment (exit 0)"* ]]
}

@test "a group that cannot be measured is a violation" {
  to_observe
  touch "$REPO/state/cv.fail"
  run p check
  [ "$status" -eq 1 ]
  [[ "$output" == *"VIOLATED: could not measure control"* ]]
  rm "$REPO/state/cv.fail"; touch "$REPO/state/ev-fault.fail"
  run p check
  [[ "$output" == *"VIOLATED: could not measure experiment"* ]]
}

@test "a control value of 0 cannot be compared" {
  to_observe
  echo 0 > "$REPO/state/cv"
  run p check
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not compare: the control value is 0"* ]]
}

@test "the baseline fails when the groups disagree before any fault" {
  echo 80 > "$REPO/state/ev"
  p start demo-kill; p guard
  run p baseline
  [ "$status" -eq 1 ]
  [[ "$output" == *"differs by 20.0% (tolerance 10%)"* ]]
  run p to inject
  [ "$status" -ne 0 ]
}

@test "the groups run at the same time" {
  sed -i 's|^echo "measured|sleep 2; echo "measured|' "$CHAOS_DIR/hypotheses/demo-kill/check"
  grep -q '^sleep 2; echo "measured' "$CHAOS_DIR/hypotheses/demo-kill/check"
  stamp
  p start demo-kill; p guard
  start=$(date +%s)
  p baseline
  (( $(date +%s) - start < 4 ))
}
