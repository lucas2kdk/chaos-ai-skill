#!/usr/bin/env bats

load helpers

setup() { make_repo; }

@test "valid binding and hypothesis pass after review" {
  stamp
  run "$SCRIPTS/validate"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok binding"* ]]
  [[ "$output" == *"ok hypothesis demo-kill"* ]]
}

@test "unreviewed binding fails unless --draft" {
  run "$SCRIPTS/validate" binding
  [ "$status" -eq 1 ]
  [[ "$output" == *"not reviewed yet"* ]]
  run "$SCRIPTS/validate" --draft binding
  [ "$status" -eq 0 ]
}

@test "binding changed after review fails" {
  stamp
  echo "# changed" >> "$CHAOS_DIR/sandbox/guard"
  run "$SCRIPTS/validate" binding
  [ "$status" -eq 1 ]
  [[ "$output" == *"changed since review"* ]]
}

@test "placeholder blast radius fails" {
  sed -i 's/^may_affect:.*/may_affect: <fill me in>/' "$CHAOS_DIR/target.md"
  run "$SCRIPTS/validate" --draft binding
  [ "$status" -eq 1 ]
  [[ "$output" == *"may_affect is empty or still a placeholder"* ]]
}

@test "sandbox target without up script fails" {
  rm "$CHAOS_DIR/sandbox/up"
  run "$SCRIPTS/validate" --draft binding
  [ "$status" -eq 1 ]
  [[ "$output" == *"sandbox/up is missing"* ]]
}

@test "existing target does not need up or down" {
  sed -i 's/^kind:.*/kind: existing/' "$CHAOS_DIR/target.md"
  rm "$CHAOS_DIR/sandbox/up" "$CHAOS_DIR/sandbox/down"
  run "$SCRIPTS/validate" --draft binding
  [ "$status" -eq 0 ]
}

@test "hypothesis with a missing file fails" {
  rm "$CHAOS_DIR/hypotheses/demo-kill/check"
  run "$SCRIPTS/validate" hypothesis demo-kill
  [ "$status" -eq 1 ]
  [[ "$output" == *"check is missing or not executable"* ]]
}

@test "non-executable fault fails" {
  chmod -x "$CHAOS_DIR/hypotheses/demo-kill/fault"
  run "$SCRIPTS/validate" hypothesis demo-kill
  [ "$status" -eq 1 ]
  [[ "$output" == *"fault is missing or not executable"* ]]
}

@test "hypothesis without a duration fails" {
  sed -i '/^duration:/d' "$CHAOS_DIR/hypotheses/demo-kill/hypothesis.md"
  run "$SCRIPTS/validate" hypothesis demo-kill
  [ "$status" -eq 1 ]
  [[ "$output" == *"duration is missing"* ]]
}

@test "duration over max_duration fails" {
  make_hypothesis long-one 10m
  run "$SCRIPTS/validate" hypothesis long-one
  [ "$status" -eq 1 ]
  [[ "$output" == *"max_duration 300s"* ]]
}

@test "non-kebab-case id fails" {
  make_hypothesis Bad_Id
  run "$SCRIPTS/validate" hypothesis Bad_Id
  [ "$status" -eq 1 ]
  [[ "$output" == *"kebab-case"* ]]
}

@test "frontmatter id must match the directory" {
  sed -i 's/^id:.*/id: other/' "$CHAOS_DIR/hypotheses/demo-kill/hypothesis.md"
  run "$SCRIPTS/validate" hypothesis demo-kill
  [ "$status" -eq 1 ]
  [[ "$output" == *"must equal the directory name"* ]]
}

@test "stamping writes chaos/.review and leaves target.md alone" {
  before="$(sha256sum "$CHAOS_DIR/target.md")"
  stamp
  [ "$(sha256sum "$CHAOS_DIR/target.md")" = "$before" ]
  grep -q '^binding: ' "$CHAOS_DIR/.review"
  grep -q '^hypothesis/demo-kill: ' "$CHAOS_DIR/.review"
}

@test "an unreviewed hypothesis fails unless --draft" {
  "$SCRIPTS/validate" --stamp binding >/dev/null
  run "$SCRIPTS/validate" hypothesis demo-kill
  [ "$status" -eq 1 ]
  [[ "$output" == *"not reviewed yet; review it, then run validate --stamp hypothesis demo-kill"* ]]
  run "$SCRIPTS/validate" --draft hypothesis demo-kill
  [ "$status" -eq 0 ]
}

@test "editing a stamped fault invalidates only that hypothesis" {
  make_hypothesis other-kill
  stamp
  echo "# edit" >> "$CHAOS_DIR/hypotheses/demo-kill/fault"
  run "$SCRIPTS/validate"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL hypothesis demo-kill: hypothesis.md, fault or check changed since review"* ]]
  [[ "$output" == *"ok hypothesis other-kill"* ]]
  [[ "$output" == *"ok binding"* ]]
}

@test "adding a helper to chaos/lib changes neither hash" {
  stamp
  mkdir -p "$CHAOS_DIR/lib"
  echo 'helper() { :; }' > "$CHAOS_DIR/lib/helpers.sh"
  run "$SCRIPTS/validate"
  [ "$status" -eq 0 ]
}

@test "a helper edited after the stamp is warned about" {
  mkdir -p "$CHAOS_DIR/lib"
  echo 'helper() { :; }' > "$CHAOS_DIR/lib/helpers.sh"
  echo 'source "$(dirname "$0")/../../lib/helpers.sh"' >> "$CHAOS_DIR/hypotheses/demo-kill/check"
  stamp
  sleep 1; touch "$CHAOS_DIR/lib/helpers.sh"
  run "$SCRIPTS/validate"
  [ "$status" -eq 0 ]
  [[ "$output" == *"warn hypothesis demo-kill: uses chaos/lib/helpers.sh, which changed after the last review stamp"* ]]
}

@test "a legacy reviewed_hash in target.md asks for a new stamp" {
  sed -i 's/^must_not_affect:.*/&\nreviewed_hash: 0123456789abcdef/' "$CHAOS_DIR/target.md"
  run "$SCRIPTS/validate" binding
  [ "$status" -eq 1 ]
  [[ "$output" == *"review stamps moved from target.md to chaos/.review"* ]]
}

@test "--stamp needs to name what was reviewed" {
  run "$SCRIPTS/validate" --stamp
  [ "$status" -eq 2 ]
  [[ "$output" == *"--stamp binding or --stamp hypothesis <id>"* ]]
}

@test "ok lines list what was checked" {
  stamp
  run "$SCRIPTS/validate"
  [[ "$output" == *"ok binding (kind=sandbox; name, may_affect, must_not_affect set; guard evidence up down executable; reviewed)"* ]]
  [[ "$output" == *"ok hypothesis demo-kill (duration 60s, wait 0s, check_timeout 20s, recovers_within 20s; fault, check executable; reviewed)"* ]]
}

@test "observation that does not fit inside the fault fails" {
  sed -i 's/^wait:.*/wait: 5s/; s/^check_timeout:.*/check_timeout: 50s/' "$CHAOS_DIR/hypotheses/demo-kill/hypothesis.md"
  run "$SCRIPTS/validate" --draft hypothesis demo-kill
  [ "$status" -eq 1 ]
  [[ "$output" == *"wait 5s + check_timeout 50s + 10s margin > duration 60s"* ]]
}

@test "defaults apply when timing fields are absent" {
  sed -i '/^wait:/d; /^check_timeout:/d; s/^duration:.*/duration: 90s/' "$CHAOS_DIR/hypotheses/demo-kill/hypothesis.md"
  run "$SCRIPTS/validate" --draft hypothesis demo-kill
  [ "$status" -eq 0 ]
  [[ "$output" == *"wait 5s, check_timeout 60s, recovers_within 65s"* ]]
}

@test "bad timing values and one_off fail" {
  sed -i 's/^wait:.*/wait: soon/' "$CHAOS_DIR/hypotheses/demo-kill/hypothesis.md"
  run "$SCRIPTS/validate" --draft hypothesis demo-kill
  [[ "$output" == *"wait is not like 5s"* ]]
  sed -i 's/^wait:.*/wait: 0s/; s/^check_timeout:.*/check_timeout: 20s\none_off: maybe/' "$CHAOS_DIR/hypotheses/demo-kill/hypothesis.md"
  run "$SCRIPTS/validate" --draft hypothesis demo-kill
  [[ "$output" == *"one_off must be true or false"* ]]
}

@test "a failing hypothesis is not reported ok after the binding already failed" {
  sed -i '/^duration:/d' "$CHAOS_DIR/hypotheses/demo-kill/hypothesis.md"
  run "$SCRIPTS/validate"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL binding: not reviewed yet"* ]]
  [[ "$output" == *"FAIL hypothesis demo-kill: frontmatter duration is missing"* ]]
  [[ "$output" != *"ok hypothesis demo-kill"* ]]
  [[ "$output" != *"not reviewed yet; review it, then run validate --stamp hypothesis"* ]]
}

@test "new frontmatter fields validate" {
  md="$CHAOS_DIR/hypotheses/demo-kill/hypothesis.md"
  sed -i 's/^duration:.*/&\nabort_interval: 2s\ncontrol: true\ntolerance: 10%\nsource: INC-1234 postmortem/' "$md"
  run "$SCRIPTS/validate" --draft hypothesis demo-kill
  [ "$status" -eq 0 ]
  [[ "$output" == *"control group within 10%"* ]]
}

@test "control without tolerance, a bad tolerance and a bad abort_interval fail" {
  md="$CHAOS_DIR/hypotheses/demo-kill/hypothesis.md"
  sed -i 's/^duration:.*/&\ncontrol: true/' "$md"
  run "$SCRIPTS/validate" --draft hypothesis demo-kill
  [[ "$output" == *"control: true needs a tolerance"* ]]
  sed -i 's/^control: true/control: true\ntolerance: ten/' "$md"
  run "$SCRIPTS/validate" --draft hypothesis demo-kill
  [[ "$output" == *"tolerance must be a percentage like 10%, got 'ten'"* ]]
  sed -i 's/^tolerance:.*/tolerance: 5%\nabort_interval: 0s/' "$md"
  run "$SCRIPTS/validate" --draft hypothesis demo-kill
  [ "$status" -eq 1 ]
  [[ "$output" == *"abort_interval must be like 5s and more than 0"* ]]
}

@test "a non-executable abort fails; an executable one is listed" {
  printf '#!/usr/bin/env bash\nexit 0\n' > "$CHAOS_DIR/hypotheses/demo-kill/abort"
  run "$SCRIPTS/validate" --draft hypothesis demo-kill
  [[ "$output" == *"abort exists but is not executable"* ]]
  chmod +x "$CHAOS_DIR/hypotheses/demo-kill/abort"
  run "$SCRIPTS/validate" --draft hypothesis demo-kill
  [ "$status" -eq 0 ]
  [[ "$output" == *", abort check;"* ]]
}

@test "adding an abort check invalidates the stamp; without one the hash is unchanged" {
  stamp
  before="$(awk '$1=="hypothesis/demo-kill:"{print $2}' "$CHAOS_DIR/.review")"
  ( source "$SCRIPTS/lib.sh"; [ "$(hypothesis_hash demo-kill)" = "$before" ] )
  printf '#!/usr/bin/env bash\nexit 0\n' > "$CHAOS_DIR/hypotheses/demo-kill/abort"
  chmod +x "$CHAOS_DIR/hypotheses/demo-kill/abort"
  run "$SCRIPTS/validate" hypothesis demo-kill
  [ "$status" -eq 1 ]
  [[ "$output" == *"changed since review"* ]]
}
