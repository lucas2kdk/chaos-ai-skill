#!/usr/bin/env bats

load helpers

DOCS="$BATS_TEST_DIRNAME/../docs"

setup() { make_repo; stamp; }

@test "every example in docs/contracts.md runs as written" {
  cd "$REPO"
  export PATH="$SCRIPTS:$PATH"
  examples="$(sed -n '/^## Examples/,$p' "$DOCS/contracts.md" | sed -n 's/^\$ //p')"
  [ -n "$examples" ]
  while IFS= read -r cmd; do
    run bash -c "$cmd"
    if [ "$status" -ne 0 ]; then echo "example failed: $cmd"; echo "$output"; false; fi
  done <<<"$examples"
  [ "$(jq -r .outcome chaos/runs/*/record.json)" = held ]
}

@test "every script in scripts/ is documented in docs/contracts.md" {
  for s in "$SCRIPTS"/*; do
    name="$(basename "$s")"
    [[ "$name" == lib.sh || "$name" == sink-* ]] && continue
    grep -q "| \`$name\`" "$DOCS/contracts.md" || { echo "undocumented: $name"; false; }
  done
}

@test "every command the guardrail hook distinguishes has a row in docs/guardrails.md" {
  hook="$BATS_TEST_DIRNAME/../hooks/guardrail"
  table="$(sed -n '/^## What each phase may run/,/^## Untrusted input/p' "$DOCS/guardrails.md")"
  for c in "phase show" "phase guard" "phase to" "phase end" "phase abort" "phase up" "phase confirm" \
           "phase fault apply" "phase fault status" "phase fault revert" "phase check" "phase evidence" \
           "phase start" "phase baseline" "phase recover" "phase reset" "phase note" pick record watchdog autorun "sink list-open" "sink create" "sink comment" "sink close" \
           sanitize lint-finding "validate --stamp"; do
    grep -q "\`$c" <<<"$table" || { echo "no row for: $c"; false; }
  done
  # and the hook still handles each of them
  for w in show guard to end abort note baseline recover reset up confirm apply status revert check evidence start pick record watchdog list-open create comment sanitize lint-finding stamp; do
    grep -q -- "$w" "$hook" || { echo "hook no longer mentions: $w"; false; }
  done
  # the read-only utilities listed in the doc match the hook
  utils="$(grep -oE '^  cat\|[a-z|]+\)' "$hook" | tr -d ' )' | tr '|' ' ')"
  grep -q "\`$utils\`" "$DOCS/guardrails.md" || { echo "utility list differs: $utils"; false; }
}

@test "every finding frontmatter field in docs/finding-format.md is checked by lint-finding" {
  for k in title severity run; do
    grep -q "^| \`$k\` | \`lint-finding\`" "$DOCS/finding-format.md" || { echo "undocumented: $k"; false; }
    grep -q "fm_get \"\$f\" $k" "$SCRIPTS/lint-finding" || { echo "not checked: $k"; false; }
  done
  grep -q 'sev-0' "$DOCS/finding-format.md"
}
