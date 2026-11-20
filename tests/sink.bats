#!/usr/bin/env bats

load helpers

setup() {
  make_repo
  make_body "$BATS_TEST_TMPDIR/body.md"
  # Stub gh: log every call, answer `issue list` from $GH_LIST_JSON and `issue create` with a URL.
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat > "$BATS_TEST_TMPDIR/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$GH_LOG"
case "$1 $2" in
  "issue list") echo "${GH_LIST_JSON:-[]}" ;;
  "issue create") echo "https://github.com/o/r/issues/7" ;;
esac
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  export GH_LOG="$BATS_TEST_TMPDIR/gh.log"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

github() { sed -i 's/^sink:.*/sink: github/' "$CHAOS_DIR/config.yaml"; }

@test "local: create, list-open, comment, close" {
  run "$SCRIPTS/sink" create demo-kill "$BATS_TEST_TMPDIR/body.md"
  [ "$status" -eq 0 ]
  [ "$output" = chaos/findings/demo-kill.md ]
  run "$SCRIPTS/sink" list-open
  [ "$output" = "demo-kill chaos/findings/demo-kill.md" ]
  echo "new evidence" > "$BATS_TEST_TMPDIR/c.md"
  "$SCRIPTS/sink" comment chaos/findings/demo-kill.md "$BATS_TEST_TMPDIR/c.md"
  grep -q "new evidence" "$CHAOS_DIR/findings/demo-kill.comments.md"
  "$SCRIPTS/sink" close chaos/findings/demo-kill.md
  run "$SCRIPTS/sink" list-open
  [ -z "$output" ]
  [ ! -e "$GH_LOG" ]
}

@test "local: a second create for an open finding is refused as a duplicate" {
  "$SCRIPTS/sink" create demo-kill "$BATS_TEST_TMPDIR/body.md"
  run "$SCRIPTS/sink" create demo-kill "$BATS_TEST_TMPDIR/body.md"
  [ "$status" -eq 3 ]
  [[ "$output" == *"use: sink comment chaos/findings/demo-kill.md"* ]]
}

@test "local: a body with a credential is not published" {
  echo "token: ghp_abcdefghijklmnopqrstuvwxyz0123" >> "$BATS_TEST_TMPDIR/body.md"
  run "$SCRIPTS/sink" create demo-kill "$BATS_TEST_TMPDIR/body.md"
  [ "$status" -ne 0 ]
  [ ! -e "$CHAOS_DIR/findings/demo-kill.md" ]
}

@test "local: a body with wrong headings is not published" {
  sed -i 's/^## Expected/## Wanted/' "$BATS_TEST_TMPDIR/body.md"
  run "$SCRIPTS/sink" create demo-kill "$BATS_TEST_TMPDIR/body.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"headings must be exactly"* ]]
}

@test "github: create labels and files the issue" {
  github
  make_body "$BATS_TEST_TMPDIR/body.md" sev-1
  run "$SCRIPTS/sink" create demo-kill "$BATS_TEST_TMPDIR/body.md"
  [ "$status" -eq 0 ]
  [ "$output" = https://github.com/o/r/issues/7 ]
  grep -q -- "issue create --title demo-kill: marker appears --label chaos-found --label sev-1 --label hyp:demo-kill" "$GH_LOG"
}

@test "github: list-open maps hyp labels to issue URLs" {
  github
  export GH_LIST_JSON='[{"url":"https://github.com/o/r/issues/3","labels":[{"name":"chaos-found"},{"name":"hyp:demo-kill"}]}]'
  run "$SCRIPTS/sink" list-open demo-kill
  [ "$output" = "demo-kill https://github.com/o/r/issues/3" ]
  run "$SCRIPTS/sink" list-open other
  [ -z "$output" ]
}

@test "github: create refuses when an open issue exists" {
  github
  export GH_LIST_JSON='[{"url":"https://github.com/o/r/issues/3","labels":[{"name":"hyp:demo-kill"}]}]'
  run "$SCRIPTS/sink" create demo-kill "$BATS_TEST_TMPDIR/body.md"
  [ "$status" -eq 3 ]
  ! grep -q "issue create" "$GH_LOG"
}

@test "unknown sink is rejected" {
  sed -i 's/^sink:.*/sink: carrier-pigeon/' "$CHAOS_DIR/config.yaml"
  run "$SCRIPTS/sink" list-open
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown sink"* ]]
}

@test "a finding without title or with a bad severity is not published, and the field is named" {
  sed -i '/^title:/d' "$BATS_TEST_TMPDIR/body.md"
  run "$SCRIPTS/sink" create demo-kill "$BATS_TEST_TMPDIR/body.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"frontmatter title is missing"* ]]
  make_body "$BATS_TEST_TMPDIR/body.md" sev-9
  run "$SCRIPTS/sink" create demo-kill "$BATS_TEST_TMPDIR/body.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"severity must be sev-0, sev-1, sev-2 or sev-3, got 'sev-9'"* ]]
  [ ! -e "$CHAOS_DIR/findings/demo-kill.md" ]
}

@test "a finding whose run has no record is not published" {
  sed -i 's/^run:.*/run: nope/' "$BATS_TEST_TMPDIR/body.md"
  run "$SCRIPTS/sink" create demo-kill "$BATS_TEST_TMPDIR/body.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"has no chaos/runs/nope/record.json"* ]]
}

@test "local: the published finding has the sink frontmatter and a generated Provenance section" {
  "$SCRIPTS/sink" create demo-kill "$BATS_TEST_TMPDIR/body.md"
  f="$CHAOS_DIR/findings/demo-kill.md"
  grep -q '^severity: sev-2$' "$f"
  grep -q '^run: r-test$' "$f"
  grep -q '^title: "demo-kill' "$f"
  [ "$(grep -c '^---$' "$f")" -eq 2 ]
  [ "$(grep '^## ' "$f" | tail -n1)" = "## Provenance" ]
  grep -q -- '- Commit: abc123 with uncommitted changes' "$f"
  grep -q -- '- Fidelity: public base image' "$f"
  grep -q -- '- Recovery after revert: NOT recovered after 60s' "$f"
  grep -q -- '- Reproduction: repeated once from a fresh start' "$f"
}

@test "a hand-written Provenance section is rejected" {
  printf '\n## Provenance\nmade up\n' >> "$BATS_TEST_TMPDIR/body.md"
  run "$SCRIPTS/sink" create demo-kill "$BATS_TEST_TMPDIR/body.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Provenance is added by the sink"* ]]
}

@test "github: sev-0 becomes a label and the issue body has no frontmatter" {
  github
  make_body "$BATS_TEST_TMPDIR/body.md" sev-0
  # capture the body file gh is given
  sed -i 's|  "issue create") echo "https://github.com/o/r/issues/7" ;;|  "issue create") for a; do [[ "$prev" == --body-file ]] \&\& cp "$a" "$GH_LOG.body"; prev=$a; done; echo "https://github.com/o/r/issues/7" ;;|' "$BATS_TEST_TMPDIR/bin/gh"
  run "$SCRIPTS/sink" create demo-kill "$BATS_TEST_TMPDIR/body.md"
  [ "$status" -eq 0 ]
  grep -q -- "label create sev-0" "$GH_LOG"
  grep -q -- "--label sev-0" "$GH_LOG"
  [ "$(head -n1 "$GH_LOG.body")" = "## Hypothesis" ]
  grep -q '^## Provenance' "$GH_LOG.body"
}

@test "local: a comment with a run gets provenance too" {
  "$SCRIPTS/sink" create demo-kill "$BATS_TEST_TMPDIR/body.md"
  printf -- '---\nrun: r-test\n---\n\nStill violated.\n' > "$BATS_TEST_TMPDIR/c.md"
  "$SCRIPTS/sink" comment chaos/findings/demo-kill.md "$BATS_TEST_TMPDIR/c.md"
  grep -q 'Still violated.' "$CHAOS_DIR/findings/demo-kill.comments.md"
  grep -q '^## Provenance' "$CHAOS_DIR/findings/demo-kill.comments.md"
  ! grep -q '^run: r-test' "$CHAOS_DIR/findings/demo-kill.comments.md"
}

@test "provenance shows source, control comparison and abort reason when present" {
  jq '.provenance += {source: "INC-1234 postmortem", control: true, tolerance_percent: 10}
      | .aborted_by = "hypothesis abort check" | .abort_output = "restarts: 3"
      | .phases += [{"phase": "check 3 exit 1", "control": 100, "experiment": 70, "diff_percent": 30}]' \
    "$CHAOS_DIR/runs/r-test/record.json" > "$CHAOS_DIR/runs/r-test/record.json.tmp"
  mv "$CHAOS_DIR/runs/r-test/record.json.tmp" "$CHAOS_DIR/runs/r-test/record.json"
  "$SCRIPTS/sink" create demo-kill "$BATS_TEST_TMPDIR/body.md"
  f="$CHAOS_DIR/findings/demo-kill.md"
  grep -q -- '- Source: INC-1234 postmortem' "$f"
  grep -q -- '- Control group: experiment 70 vs control 100, 30% difference (tolerance 10%)' "$f"
  grep -q -- '- Stopped early by the hypothesis abort check: restarts: 3' "$f"
}

@test "provenance leaves those lines out when they do not apply" {
  "$SCRIPTS/sink" create demo-kill "$BATS_TEST_TMPDIR/body.md"
  ! grep -q -e '- Source:' -e '- Control group:' -e '- Stopped early' "$CHAOS_DIR/findings/demo-kill.md"
}
