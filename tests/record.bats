#!/usr/bin/env bats

load helpers

setup() { make_repo; }

@test "writes a held record" {
  run "$SCRIPTS/record" r1 demo-kill held
  [ "$status" -eq 0 ]
  f="$CHAOS_DIR/runs/r1/record.json"
  [ "$(jq -r .outcome "$f")" = held ]
  [ "$(jq -r .finding "$f")" = null ]
  [ "$(jq -r .hypothesis "$f")" = demo-kill ]
}

@test "rejects an invalid outcome" {
  run "$SCRIPTS/record" r1 demo-kill exploded
  [ "$status" -eq 2 ]
  [[ "$output" == *"bad outcome"* ]]
  [ ! -e "$CHAOS_DIR/runs/r1/record.json" ]
}

@test "violated needs a finding reference" {
  run "$SCRIPTS/record" r1 demo-kill violated
  [ "$status" -eq 2 ]
  run "$SCRIPTS/record" r1 demo-kill violated chaos/findings/demo-kill.md
  [ "$status" -eq 0 ]
  [ "$(jq -r .finding "$CHAOS_DIR/runs/r1/record.json")" = chaos/findings/demo-kill.md ]
}

@test "keeps the phase log and start time already in the record" {
  mkdir -p "$CHAOS_DIR/runs/r1"
  echo '{"started_at":"2026-01-01T00:00:00Z","phases":[{"phase":"plan"}]}' > "$CHAOS_DIR/runs/r1/record.json"
  "$SCRIPTS/record" --failed-phase inject r1 demo-kill aborted
  f="$CHAOS_DIR/runs/r1/record.json"
  [ "$(jq -r .started_at "$f")" = 2026-01-01T00:00:00Z ]
  [ "$(jq -r '.phases[0].phase' "$f")" = plan ]
  [ "$(jq -r .failed_phase "$f")" = inject ]
}

@test "an unattended run may record violated without a finding, marked for triage" {
  mkdir -p "$CHAOS_DIR/runs/r1"
  echo '{"mode": "auto", "phases": []}' > "$CHAOS_DIR/runs/r1/record.json"
  run "$SCRIPTS/record" r1 demo-kill violated
  [ "$status" -eq 0 ]
  [ "$(jq -r .needs_triage "$CHAOS_DIR/runs/r1/record.json")" = true ]
  [ "$(jq -r .finding "$CHAOS_DIR/runs/r1/record.json")" = null ]
}

@test "an interactive run still needs the finding reference" {
  mkdir -p "$CHAOS_DIR/runs/r2"
  echo '{"mode": "run", "phases": []}' > "$CHAOS_DIR/runs/r2/record.json"
  run "$SCRIPTS/record" r2 demo-kill violated
  [ "$status" -eq 2 ]
}
