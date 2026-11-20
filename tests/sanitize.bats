#!/usr/bin/env bats

load helpers

@test "redacts a GitHub token" {
  run bash -c "echo 'auth ghp_abcdefghijklmnopqrstuvwxyz0123 ok' | '$SCRIPTS/sanitize'"
  [ "$output" = "auth [REDACTED] ok" ]
}

@test "redacts a password assignment and keeps the key" {
  run bash -c "echo 'db password=hunter2hunter2 port=5432' | '$SCRIPTS/sanitize'"
  [ "$output" = "db password=[REDACTED] port=5432" ]
}

@test "redacts an email address" {
  run bash -c "echo 'user jane.doe@example.com logged in' | '$SCRIPTS/sanitize'"
  [ "$output" = "user [REDACTED-EMAIL] logged in" ]
}

@test "leaves clean text alone and does not touch existing markers" {
  run bash -c "printf 'GET /cart 200 in 0.12s\ntoken: [REDACTED]\n' | '$SCRIPTS/sanitize'"
  [ "$output" = $'GET /cart 200 in 0.12s\ntoken: [REDACTED]' ]
}

@test "reads a file argument" {
  echo 'Bearer abcdefghijklmnop1234' > "$BATS_TEST_TMPDIR/in"
  run "$SCRIPTS/sanitize" "$BATS_TEST_TMPDIR/in"
  [ "$output" = "Bearer [REDACTED]" ]
}

@test "--detect exits 1 and names the line on a match" {
  printf 'line one\nkey AKIAABCDEFGHIJKLMNOP\n' > "$BATS_TEST_TMPDIR/in"
  run "$SCRIPTS/sanitize" --detect "$BATS_TEST_TMPDIR/in"
  [ "$status" -eq 1 ]
  [[ "$output" == *"line(s) 2"* ]]
}

@test "--detect exits 0 on clean or already redacted text" {
  printf 'all fine\napi_key: [REDACTED]\n' > "$BATS_TEST_TMPDIR/in"
  run "$SCRIPTS/sanitize" --detect "$BATS_TEST_TMPDIR/in"
  [ "$status" -eq 0 ]
}
