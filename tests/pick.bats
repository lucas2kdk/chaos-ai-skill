#!/usr/bin/env bats

load helpers

setup() {
  make_repo
  make_hypothesis other-kill
  stamp
  make_body "$BATS_TEST_TMPDIR/body.md"
}

@test "picks the first hypothesis without an open finding" {
  run "$SCRIPTS/pick"
  [ "$status" -eq 0 ]
  [ "$output" = demo-kill ]
  "$SCRIPTS/sink" create demo-kill "$BATS_TEST_TMPDIR/body.md"
  run "$SCRIPTS/pick"
  [ "$output" = other-kill ]
}

@test "exits 1 when every hypothesis is covered" {
  "$SCRIPTS/sink" create demo-kill "$BATS_TEST_TMPDIR/body.md"
  "$SCRIPTS/sink" create other-kill "$BATS_TEST_TMPDIR/body.md"
  run "$SCRIPTS/pick"
  [ "$status" -eq 1 ]
  [[ "$output" == *"all 2 valid hypotheses already have an open finding"* ]]
}

@test "a closed finding makes the hypothesis eligible again" {
  "$SCRIPTS/sink" create demo-kill "$BATS_TEST_TMPDIR/body.md"
  "$SCRIPTS/sink" close chaos/findings/demo-kill.md
  run "$SCRIPTS/pick"
  [ "$output" = demo-kill ]
}

@test "skips invalid hypotheses" {
  sed -i '/^duration:/d' "$CHAOS_DIR/hypotheses/demo-kill/hypothesis.md"
  run "$SCRIPTS/pick"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping demo-kill: frontmatter duration is missing"* ]]
  [ "${lines[-1]}" = other-kill ]
}

@test "says so when there are no valid hypotheses" {
  rm -r "$CHAOS_DIR/hypotheses"
  run "$SCRIPTS/pick"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no valid, reviewed hypotheses"* ]]
}

@test "skips hypotheses that are not reviewed" {
  make_hypothesis aaa-new
  run "$SCRIPTS/pick"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping aaa-new: not reviewed yet"* ]]
  [ "${lines[-1]}" = demo-kill ]
}
