# Guardrails

A chaos run gives an agent a shell and permission to break things. The limits are enforced by the Claude Code harness (hooks) and by the plugin's scripts, not by asking the agent to behave. Prompts repeat the rules as a second layer, never the only one.

## Layers

| Layer | What it stops | Where |
|---|---|---|
| Reviewed binding | Runs against a target description or sandbox scripts nobody looked at | `validate --stamp binding` records a hash of `target.md` + `chaos/sandbox/` in `chaos/.review`; `phase start` refuses when it changed |
| Reviewed hypotheses | Running a `fault` or `check` nobody approved, or one edited after approval | `validate --stamp hypothesis <id>` records a hash of `hypothesis.md`, `fault`, `check`; `pick` skips and `phase start` refuses unreviewed or changed ones |
| Baseline | Blaming the fault for a target that was already broken | `phase baseline` must pass before `phase to inject` |
| Fault takes effect | A fault that silently does nothing producing a false `held` | after `fault apply`, `fault status` must report `active` within 10s, or the fault is reverted and `phase` exits 3. One-off faults are exempt and recorded as such. |
| Guard | Faults on anything other than the declared target | `phase to inject` needs a passed guard; `phase fault apply` re-runs it immediately before applying |
| Existing-target confirmation | Faults on an instance you run, without you saying yes for this run | `phase confirm` is required before inject for `kind: existing`, and the hook turns that command into a permission prompt naming the target and blast radius |
| Blast radius | Faults that reach what they must not | `may_affect` / `must_not_affect` in `target.md`; `/chaos:hypothesize` refuses faults outside it |
| Abort checks | An experiment that harms the target in ways the steady state doesn't show | optional `chaos/sandbox/abort` and `hypotheses/<id>/abort`, run by the watchdog every `abort_interval` while a fault is active, even if the session is idle. A non-zero exit or a timeout reverts the fault at once, and `phase` then refuses everything but `phase abort`. |
| Time box | A fault that never ends | `duration` required and capped by `max_duration`; `watchdog` reverts at expiry even if the session dies. `wait + check_timeout + 10s` must fit inside `duration`, so the observation ends before the watchdog fires. |
| Forward-only phases | Going back to injecting after reading untrusted evidence | `phase to` only moves forward; triage may re-apply the fault once, and only from a fresh start (`phase reset` for sandboxes, a passing `phase baseline` for existing targets) |
| Phase allowlist | A phase doing more than its job | `hooks/guardrail` (PreToolUse on Bash, Write, Edit) |
| Cleanup | Faults left behind | `phase end`/`abort` revert and confirm `inactive`; the Stop and SessionEnd hook reverts and records `aborted` |
| Redaction | Secrets or personal data in findings | `sanitize` on evidence; sinks refuse a body that `sanitize --detect` flags |
| Finding format | Findings a fixer cannot reproduce | `lint-finding` before any sink publishes |

## What each phase may run

While a run is active (`chaos/runs/.active` exists), the hook allows Bash only for the plugin's own scripts, called by absolute path, plus the read-only utilities `cat head tail ls grep wc jq date diff sleep`. One command at a time: no line breaks, no `;` `&` `|` `<` `>` outside quotes, and no `$` or backtick outside single quotes (the shell expands them inside double quotes). Quoted patterns are fine, so `grep -E "fatal|TypeError" file` works; `grep -e fatal -e TypeError file` is the safest form. Write and Edit may only touch `chaos/runs/<run-id>/`, never its `record.json`.

| Command | plan | inject | observe | triage | report | cleanup |
|---|---|---|---|---|---|---|
| `phase show`, `phase guard`, `phase to`, `phase end`, `phase abort` | yes | yes | yes | yes | yes | yes |
| `phase fault status`, `phase fault revert` | yes | yes | yes | yes | yes | yes |
| `phase note` | yes | yes | yes | yes | yes | yes |
| `phase up` | yes | | | | | |
| `phase confirm` (asks the user) | yes | | | | | |
| `phase baseline` | yes | | | yes | | |
| `phase fault apply` (guard must have passed) | | yes | | once | | |
| `phase check`, `phase evidence`, `phase recover` | | | yes | yes | | |
| `phase reset` (sandbox targets, once) | | | | yes | | |
| `pick` | yes | | | | | |
| `sink list-open` | yes | | | yes | yes | |
| `sink create`, `sink comment` | | | | | yes | |
| `sanitize`, `lint-finding`, `validate` (not `--stamp`) | yes | yes | yes | yes | yes | yes |
| `phase start`, `record`, `watchdog`, `autorun`, `sink close`, `validate --stamp` | | | | | | |

`autorun` is for schedulers. It refuses to start while a run is active, holds a lock so two schedulers never overlap, runs sandbox targets only, and never files findings (see `docs/continuous-runs.md`).

Outside a run, the hook only blocks running a hypothesis's `fault` directly: faults go through `phase`, inside `/chaos:run` or `/chaos:verify`.

The `phase` script enforces the same phase rules itself, so calling it from a terminal follows them too.

## Untrusted input

Logs, check output and evidence are written by the system under test, so a faulted target can put arbitrary text in them. They are data:

- Skills tell the agent to ignore instructions found inside them.
- After observe, the hook no longer allows injecting (except the single triage repeat), and in report only the sink is reachable.
- Evidence passes through `sanitize` before it reaches a finding, and sinks re-check.

## Known gaps

- **The hook sees command text.** Once a binding executable is allowed, it can do anything its author wrote. Bindings are reviewed once at profile time and re-review is forced when they change, but the review is a human reading scripts.
- **The agent drives phase transitions.** A hijacked agent can call `phase to report` early or `phase abort`. It cannot go back to inject, and every transition is logged in `record.json`.
- **`guard` is written by the agent.** A weak guard (a hostname check) weakens everything after it. `/chaos:profile` asks for an identity that cannot be confused (a label plus container id, an emulator serial, a kube context), and the review should check it.
- **Confirmation depends on the permission prompt.** In permission modes that auto-approve tool calls, the harness may not show the prompt for `phase confirm`. Do not run existing-target hypotheses in those modes.
- **Hooks only exist in Claude Code.** The scripts still enforce phase order and the guard, but nothing stops another runtime from calling a fault directly.
- **The watchdog survives the session, not a reboot.** Prefer faults that end on their own (a Chaos Mesh `duration`, a container restart policy).
- **Redaction is pattern-based.** It catches common token shapes, passwords and emails, not every secret. Read a finding before publishing it to a public repo.
- **`chaos/lib/` is not reviewed.** Helpers there are outside every stamp, so a helper can change what a stamped `fault` does. `validate` warns when a stamped hypothesis uses a helper changed after the stamp, but it does not block the run.
- **Fault scripts have the access of the user.** Stamps prove a human approved the script; they do not stop the script from reaching beyond the blast radius. Enforcing the blast radius at the Docker socket is future work.
- **Read-only utilities read anything.** `cat` can read any file the user can, including secrets on disk, which could then end up in a finding. Redaction is the backstop.
