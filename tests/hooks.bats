#!/usr/bin/env bats

load helpers

HOOKS="$(cd "$BATS_TEST_DIRNAME/../hooks" && pwd -P)"

setup() { make_repo; stamp; }

teardown() {
  local pid
  pid="$(jq -r '.watchdog_pid // empty' "$CHAOS_DIR/runs/.active" 2>/dev/null || true)"
  [[ -n "$pid" ]] && kill -- "-$pid" 2>/dev/null || true
}

# bash_call <command>: run the guardrail on a Bash tool call; sets $decision ("allow" when silent) and $reason.
bash_call() { hook_call "$(jq -n --arg c "$1" --arg cwd "$REPO" '{tool_name: "Bash", cwd: $cwd, tool_input: {command: $c}}')"; }
write_call() { hook_call "$(jq -n --arg p "$1" --arg cwd "$REPO" '{tool_name: "Write", cwd: $cwd, tool_input: {file_path: $p, content: "x"}}')"; }
hook_call() {
  local out
  out="$("$HOOKS/guardrail" <<<"$1")"
  decision="$(jq -r '.hookSpecificOutput.permissionDecision // "allow"' <<<"${out:-{\}}")"
  reason="$(jq -r '.hookSpecificOutput.permissionDecisionReason // ""' <<<"${out:-{\}}")"
}
p() { "$SCRIPTS/phase" "$@" >/dev/null; }
start_run() { p start demo-kill; RUN="$(jq -r .run "$CHAOS_DIR/runs/.active")"; }

@test "outside a repo with chaos/ everything is allowed" {
  out="$("$HOOKS/guardrail" <<<'{"tool_name":"Bash","cwd":"/","tool_input":{"command":"rm -rf build"}}')"
  [ -z "$out" ]
}

@test "no run: ordinary commands are allowed" {
  bash_call "npm test && echo done"
  [ "$decision" = allow ]
}

@test "no run: running a fault directly is denied" {
  bash_call "chaos/hypotheses/demo-kill/fault apply"
  [ "$decision" = deny ]
  [[ "$reason" == *"only run through"* ]]
  bash_call "./chaos/hypotheses/demo-kill/check"
  [ "$decision" = allow ]
}

@test "run: chaining, pipes, redirects and expansion are denied" {
  start_run
  for c in "$SCRIPTS/phase show; rm -rf /" "$SCRIPTS/phase show | tee x" "cat a > b" 'echo $HOME' "$SCRIPTS/phase show && ls"; do
    bash_call "$c"
    [ "$decision" = deny ]
  done
}

@test "run: arbitrary commands are denied, read-only utilities allowed" {
  start_run
  bash_call "docker kill api"
  [ "$decision" = deny ]
  [[ "$reason" == *"may only run the chaos plugin's scripts"* ]]
  bash_call "cat chaos/target.md"
  [ "$decision" = allow ]
}

@test "run: a script with the same name outside the plugin is denied" {
  start_run
  mkdir -p "$REPO/scripts"; cp "$SCRIPTS/phase" "$REPO/scripts/phase"
  bash_call "$REPO/scripts/phase fault apply"
  [ "$decision" = deny ]
}

@test "run: guard-first for fault apply" {
  start_run
  bash_call "$SCRIPTS/phase fault apply"
  [ "$decision" = deny ]
  [[ "$reason" == *"guard has not passed"* ]]
}

@test "run: inject allows only the fault, not check" {
  start_run; p guard; p baseline; p to inject
  bash_call "$SCRIPTS/phase fault apply"
  [ "$decision" = allow ]
  bash_call "$SCRIPTS/phase check"
  [ "$decision" = deny ]
  [[ "$reason" == *"phase inject"* ]]
}

@test "run: observe allows check and evidence, not fault apply or sink create" {
  start_run; p guard; p baseline; p to inject; p to observe
  bash_call "$SCRIPTS/phase check"
  [ "$decision" = allow ]
  bash_call "$SCRIPTS/phase evidence"
  [ "$decision" = allow ]
  bash_call "$SCRIPTS/phase fault apply"
  [ "$decision" = deny ]
  bash_call "$SCRIPTS/sink create demo-kill sev-2 t body.md"
  [ "$decision" = deny ]
}

@test "run: triage allows the repeat fault apply" {
  start_run; p guard; p baseline; p to inject; p to observe; p to triage
  bash_call "$SCRIPTS/phase fault apply"
  [ "$decision" = allow ]
}

@test "run: report allows the sink, not the target" {
  start_run; p guard; p baseline; p to inject; p to observe; p to triage; p to report
  bash_call "$SCRIPTS/sink create demo-kill sev-2 t body.md"
  [ "$decision" = allow ]
  bash_call "$SCRIPTS/phase check"
  [ "$decision" = deny ]
  bash_call "$SCRIPTS/phase fault apply"
  [ "$decision" = deny ]
  bash_call "curl http://localhost:8080"
  [ "$decision" = deny ]
}

@test "run: record, watchdog, start and --stamp are denied" {
  start_run
  for c in "$SCRIPTS/record r demo-kill held" "$SCRIPTS/watchdog x y 1" "$SCRIPTS/phase start demo-kill" "$SCRIPTS/validate --stamp"; do
    bash_call "$c"
    [ "$decision" = deny ]
  done
}

@test "run: confirm asks the user and names the blast radius" {
  start_run
  bash_call "$SCRIPTS/phase confirm"
  [ "$decision" = ask ]
  [[ "$reason" == *"test target"* ]]
  [[ "$reason" == *"marker files in state/"* ]]
}

@test "run: writes only inside the run directory" {
  start_run
  write_call "$CHAOS_DIR/runs/$RUN/finding.md"
  [ "$decision" = allow ]
  write_call "chaos/runs/$RUN/notes.md"
  [ "$decision" = allow ]
  write_call "$CHAOS_DIR/runs/$RUN/record.json"
  [ "$decision" = deny ]
  write_call "$CHAOS_DIR/runs/$RUN/../../sandbox/guard"
  [ "$decision" = deny ]
  write_call "$REPO/src/app.js"
  [ "$decision" = deny ]
}

@test "stop hook reverts an active fault and records aborted" {
  start_run; p guard; p baseline; p to inject; p fault apply
  [ -e "$REPO/state/fault-demo-kill" ]
  out="$("$HOOKS/revert-on-stop" <<<"{\"hook_event_name\":\"Stop\",\"cwd\":\"$REPO\"}")"
  [[ "$(jq -r .systemMessage <<<"$out")" == *"was reverted"* ]]
  [ ! -e "$REPO/state/fault-demo-kill" ]
  [ ! -e "$CHAOS_DIR/runs/.active" ]
  [ "$(jq -r .outcome "$CHAOS_DIR/runs/$RUN/record.json")" = aborted ]
}

@test "stop hook leaves a run without an active fault alone" {
  start_run; p guard
  out="$("$HOOKS/revert-on-stop" <<<"{\"hook_event_name\":\"Stop\",\"cwd\":\"$REPO\"}")"
  [ -z "$out" ]
  [ -e "$CHAOS_DIR/runs/.active" ]
}

@test "run: | inside a quoted pattern is allowed, a real pipe is not" {
  start_run
  bash_call 'grep -E "fatal|TypeError" chaos/target.md'
  [ "$decision" = allow ]
  bash_call "grep -E 'fatal|TypeError' chaos/target.md"
  [ "$decision" = allow ]
  bash_call 'grep -E fatal chaos/target.md | wc -l'
  [ "$decision" = deny ]
  [[ "$reason" == *"found '|'"* ]]
  [[ "$reason" == *"grep -e"* ]]
}

@test "run: \$ is expansion inside double quotes but not inside single quotes" {
  start_run
  bash_call 'grep "$HOME" chaos/target.md'
  [ "$decision" = deny ]
  bash_call "grep '\$HOME' chaos/target.md"
  [ "$decision" = allow ]
  bash_call 'grep "`id`" chaos/target.md'
  [ "$decision" = deny ]
}

@test "run: quotes do not hide chaining after they close, and line breaks are refused" {
  start_run
  bash_call 'grep "a" chaos/target.md; rm -rf chaos'
  [ "$decision" = deny ]
  bash_call 'grep "a;b" chaos/target.md'
  [ "$decision" = allow ]
  bash_call $'cat chaos/target.md\nrm -rf chaos'
  [ "$decision" = deny ]
  [[ "$reason" == *"no line breaks"* ]]
}

@test "run: baseline, recover, reset and note are allowed only in their phases" {
  start_run
  bash_call "$SCRIPTS/phase baseline";  [ "$decision" = allow ]
  bash_call "$SCRIPTS/phase recover";   [ "$decision" = deny ]
  bash_call "$SCRIPTS/phase reset";     [ "$decision" = deny ]
  bash_call "$SCRIPTS/phase note 'skipped the repeat'"; [ "$decision" = allow ]
  p guard; p baseline; p to inject; p to observe
  bash_call "$SCRIPTS/phase recover";   [ "$decision" = allow ]
  bash_call "$SCRIPTS/phase baseline";  [ "$decision" = deny ]
  bash_call "$SCRIPTS/phase reset";     [ "$decision" = deny ]
  p to triage
  bash_call "$SCRIPTS/phase reset";     [ "$decision" = allow ]
  bash_call "$SCRIPTS/phase baseline";  [ "$decision" = allow ]
  bash_call "$SCRIPTS/phase recover";   [ "$decision" = allow ]
  p to report
  bash_call "$SCRIPTS/phase reset";     [ "$decision" = deny ]
  bash_call "$SCRIPTS/phase note done"; [ "$decision" = allow ]
}

@test "run: autorun is blocked during a run; outside a run it is allowed" {
  bash_call "$SCRIPTS/autorun --all"
  [ "$decision" = allow ]
  start_run
  bash_call "$SCRIPTS/autorun --all"
  [ "$decision" = deny ]
  [[ "$reason" == *"autorun is not allowed during a run"* ]]
}
