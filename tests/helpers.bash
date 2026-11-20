# Shared by tests/*.bats. Builds a throwaway repo with a valid chaos/ binding in $BATS_TEST_TMPDIR.

SCRIPTS="$(cd "$BATS_TEST_DIRNAME/../scripts" && pwd -P)"

# make_repo: creates $REPO/chaos with a sandbox binding and one hypothesis "demo-kill".
# The sandbox and fault scripts only touch marker files under $REPO/state.
make_repo() {
  REPO="$BATS_TEST_TMPDIR/repo"
  export CHAOS_DIR="$REPO/chaos"
  mkdir -p "$CHAOS_DIR/sandbox" "$REPO/state"
  cat > "$CHAOS_DIR/config.yaml" <<'EOF'
sink: local
max_duration: 300s
keep_sandbox: false
EOF
  cat > "$CHAOS_DIR/target.md" <<'EOF'
---
kind: sandbox
name: test target
may_affect: marker files in state/
must_not_affect: anything else
---
# Target
EOF
  local s
  for s in up down guard evidence; do
    printf '#!/usr/bin/env bash\necho %s >> "%s/state/sandbox.log"\n' "$s" "$REPO" > "$CHAOS_DIR/sandbox/$s"
  done
  printf '#!/usr/bin/env bash\nmkdir -p "$1"; echo "log line" > "$1/app.log"\n' > "$CHAOS_DIR/sandbox/evidence"
  chmod +x "$CHAOS_DIR"/sandbox/*
  make_hypothesis demo-kill 60s
}

# make_hypothesis <id> [duration]: fault toggles $REPO/state/fault-<id>; check fails while it exists.
make_hypothesis() {
  local id=$1 dur=${2:-60s} dir="$CHAOS_DIR/hypotheses/$1"
  mkdir -p "$dir"
  cat > "$dir/hypothesis.md" <<EOF
---
id: $id
steady_state: marker file absent
fault: create a marker file
duration: $dur
wait: 0s
check_timeout: 20s
---
**Steady state:** the marker file is absent.
EOF
  cat > "$dir/fault" <<EOF
#!/usr/bin/env bash
m="$REPO/state/fault-$id"
case "\$1" in
  apply) touch "\$m" ;;
  revert) rm -f "\$m"; echo reverted >> "$REPO/state/revert-$id.log" ;;
  status) if [[ -e "\$m" ]]; then echo active; else echo inactive; fi ;;
esac
EOF
  cat > "$dir/check" <<EOF
#!/usr/bin/env bash
if [[ -e "$REPO/state/fault-$id" ]]; then echo "VIOLATED marker present"; exit 1; fi
echo ok
EOF
  chmod +x "$dir/fault" "$dir/check"
}

# stamp: record the binding and every hypothesis as reviewed.
stamp() {
  "$SCRIPTS/validate" --stamp binding >/dev/null
  local d
  for d in "$CHAOS_DIR"/hypotheses/*/; do
    "$SCRIPTS/validate" --stamp hypothesis "$(basename "$d")" >/dev/null
  done
}

# make_body <path> [severity]: a finding that passes lint-finding, for run r-test (whose record it creates).
make_body() {
  mkdir -p "$CHAOS_DIR/runs/r-test"
  [[ -f "$CHAOS_DIR/runs/r-test/record.json" ]] || cat > "$CHAOS_DIR/runs/r-test/record.json" <<'EOF2'
{"run": "r-test", "mode": "run", "started_at": "2026-11-09T15:00:00Z",
 "provenance": {"commit": "abc123", "dirty": true, "binding_hash": "b1", "hypothesis_hash": "h1", "fidelity": "public base image", "one_off": false},
 "baseline": "pass", "recovered": false, "observed_without_recovery_seconds": 60, "reproduction": "repeated",
 "phases": [{"phase": "check 1 exit 1"}, {"phase": "check 2 exit 1"}]}
EOF2
  printf -- '---\ntitle: "demo-kill: marker appears"\nseverity: %s\nrun: r-test\n---\n\n' "${2:-sev-2}" > "$1"
  cat >> "$1" <<'EOF2'
## Hypothesis
demo-kill: marker file absent.

## Expected
The check exits 0 while the fault is active.

## Observed
The check exits 1. Severity: sev-2.

## Reproduction
### Fault
`chaos/hypotheses/demo-kill/fault apply`
### Steps
1. Run the guard. 2. Apply the fault. 3. Run the check. 4. Revert.
### Check command
`chaos/hypotheses/demo-kill/check`

## Evidence
```
2026-11-09T15:00:00Z VIOLATED marker present
```

## Suspected cause (unverified hypothesis)
None given.
EOF2
}
