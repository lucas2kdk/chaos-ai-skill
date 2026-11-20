# Contracts

Everything the plugin knows about a target goes through a few files and executables in the repo's `chaos/` directory. Executables can be written in any language: only their arguments, output and exit codes matter.

```
chaos/
  config.yaml          plugin settings for this repo
  target.md            what the target is, its blast radius, fidelity note
  .review              review stamps: "binding: <hash>", "hypothesis/<id>: <hash>"  (written by validate --stamp)
  sandbox/             up, down, guard, evidence            (the reviewed binding)
  lib/                 helpers shared by hypotheses          (not part of any stamp)
  hypotheses/<id>/     hypothesis.md, fault, check          (each reviewed and stamped)
  runs/<run-id>/       record.json, check-<n>.out, evidence/, finding.md   (written by runs)
  findings/            findings written by the local sink
```

## Binding executables

| Executable | Arguments | Must | Exit |
|---|---|---|---|
| `sandbox/up` | none | create a disposable instance that `guard` can identify. Sandbox targets only. | 0 when the instance is ready |
| `sandbox/down` | none | destroy what `up` created. Sandbox targets only. | 0 when it is gone |
| `sandbox/guard` | none | prove the live target is the one `target.md` declares (label and id, emulator serial, kube context). Never change anything. | 0 only on a match |
| `sandbox/evidence` | `<out-dir> <since>` | write timestamped logs and state since `<since>` (ISO 8601 UTC) into `<out-dir>`. Never change the target. | 0 on success |
| `hypotheses/<id>/fault` | `apply`, `revert` or `status` | `apply`: start the fault. `revert`: end it, safe to call any number of times. `status`: print `active` or `inactive` on the first line. | 0 on success |
| `hypotheses/<id>/check` | none, or `control` / `experiment` for control-group hypotheses | probe the steady state, print what it measured. Control-group checks print `value: <number>` for the named group. Never change the target. | 0 = steady state holds (or, for a group, measured), non-zero = violated or could not measure |
| `hypotheses/<id>/abort` and `sandbox/abort` | none | optional. Watch internal signals (CPU, queue depth, error rate, restarts) while a fault is active. Never change the target. | 0 = keep going, non-zero or a timeout = stop the experiment now |

## `target.md`

Frontmatter (flat `key: value` lines):

| Key | Meaning |
|---|---|
| `kind` | `sandbox` (created by `up`, removed by `down`) or `existing` (an instance you already run; every run asks you to confirm it) |
| `name` | short name shown when asking for confirmation |
| `may_affect` | what faults may touch |
| `must_not_affect` | what faults must never touch |
| `fidelity` | optional: how the target differs from production (e.g. a public base image instead of the internal one). Copied into every run record and finding. |

Review stamps are not in `target.md`. `validate --stamp binding` hashes `target.md` and every file in `sandbox/` into `chaos/.review`; runs refuse to start when they changed since. An old `reviewed_hash:` line from an earlier plugin version is ignored, and `validate` asks for a new stamp.

The body describes the target, its steady-state signals, how `guard` proves identity and what `evidence` collects. See `templates/target.md`.

## `hypothesis.md`

Frontmatter (durations like `90s`, `5m`, `1h`):

| Key | Default | Meaning |
|---|---|---|
| `id` | required | equals the directory name, kebab-case |
| `steady_state` | required | one measurable sentence |
| `fault` | required | one line describing the fault |
| `duration` | required | the fault ends or is reverted after this; at most `max_duration` |
| `wait` | `5s` | time between applying the fault and running the check; `phase check` waits by itself |
| `check_timeout` | `60s` | longest the check may run; a check that runs longer counts as violated |
| `recovers_within` | `wait + check_timeout` | after revert, how long the steady state may take to hold again |
| `one_off` | `false` | `true` for a single event with nothing to revert (a process kill): `status` may stay `inactive`, and the run does not assert the fault took effect |
| `abort_interval` | `5s` | how often the abort checks run while the fault is active |
| `control` | `false` | `true`: the check measures a control and an experimental group at the same time (see below) |
| `tolerance` | required with `control` | how far the experimental value may differ from the control value, like `10%` |
| `source` | none | the incident, postmortem or document the hypothesis came from; shown in findings |

`validate` rejects a hypothesis where `wait + check_timeout + 10s` is more than `duration`, so the observation always ends before the watchdog reverts the fault.

A hypothesis is runnable only after review: `validate --stamp hypothesis <id>` hashes `hypothesis.md`, `fault`, `check` and, when present, `abort` into `chaos/.review`. Editing any of them blocks runs until it is reviewed and stamped again. Helpers in `chaos/lib/` are not hashed; `validate` warns when a stamped `fault` or `check` uses a helper changed after the stamp. The body explains why the hypothesis matters.

## Control groups

Before/after comparison works for a sandbox with no outside traffic. When the steady state drifts on its own (real users, time of day), compare an experimental group against a control group measured at the same time instead.

- `control: true` and `tolerance: 10%` in `hypothesis.md`.
- `check control` and `check experiment` each measure one group and print `value: <number>` (the last such line counts). Exit non-zero if the group could not be measured.
- `fault` must affect the experimental group only. The plugin does not route traffic.
- `phase check`, `baseline` and `recover` run both at once and pass while `|experiment - control| / control <= tolerance`. The baseline fails if the groups already disagree before any fault.

Example: two replicas of an API behind their own ports, where the fault adds latency to replica B only.

```bash
#!/usr/bin/env bash
# check: requests per second that succeed within 500ms, per replica
case "$1" in
  control)    url=http://127.0.0.1:18081/items ;;   # replica A, untouched
  experiment) url=http://127.0.0.1:18082/items ;;   # replica B, the fault's target
  *) exit 2 ;;
esac
ok=0
for i in $(seq 1 20); do curl -fs -m 0.5 -o /dev/null "$url" && ok=$((ok + 1)); done
echo "value: $ok"
```

## `config.yaml`

| Key | Default | Meaning |
|---|---|---|
| `sink` | `local` | where findings go: `local` or `github` |
| `max_duration` | `300s` | longest fault any hypothesis may declare |
| `keep_sandbox` | `false` | leave the sandbox up after a run |

## Run record

`chaos/runs/<run-id>/record.json`, written only by `phase` and `record`:

```json
{
  "run": "20261109T150422Z",
  "hypothesis": "api-kill",
  "mode": "run | verify | auto",
  "needs_triage": "true for an unattended (auto) run that was violated: no finding was filed",
  "outcome": "held | violated | not-reproducible | aborted",
  "finding": "chaos/findings/api-kill.md or an issue URL, null unless violated",
  "failed_phase": "null, or the phase an aborted run stopped in",
  "note": "free text, e.g. why it aborted",
  "started_at": "...", "ended_at": "...",
  "provenance": {
    "commit": "git HEAD, or null outside git", "dirty": "true when the tree has uncommitted changes",
    "binding_hash": "...", "hypothesis_hash": "...", "fidelity": "target.md fidelity note or null",
    "one_off": false
  },
  "baseline": "pass | fail | null",
  "aborted_by": "null, or target abort check / hypothesis abort check", "abort_output": "first line of its output",
  "recovered": "true | false | null", "recovery_seconds": 12,
  "reproduction": "repeated once triage re-applies the fault, skipped when an existing target had not recovered, else null",
  "notes": ["added with phase note"],
  "phases": [
    {"phase": "guard passed", "at": "...", "output": "first line of guard's output"},
    {"phase": "fault applied", "at": "...", "status_after": "active"},
    {"phase": "check 2 exit 1", "at": "...", "exit": 1, "summary": "first VIOLATED line, else the last line"},
    {"phase": "fault reverted", "at": "...", "status_after": "inactive"}
  ]
}
```

## Plugin scripts

All live in the plugin's `scripts/` and find `chaos/` by walking up from the current directory (or `$CHAOS_DIR`).

| Script | Usage | Exit |
|---|---|---|
| `validate` | `validate [--draft] [binding \| hypothesis <id> \| all]`; `validate --stamp binding`, `validate --stamp hypothesis <id>`. `--draft` skips the review check; `--stamp` records what you reviewed in `chaos/.review`. Prints `ok ... (what was checked)`, `FAIL ...: why`, `warn ...: why`. | 0 valid, 1 not, 2 bad arguments |
| `pick` | `pick`: prints the first valid, reviewed hypothesis without an open finding; says why it skips others | 0 picked, 1 nothing to test |
| `phase` | drives a run; see below | non-zero when a step is refused or fails; 3 when a fault did not take effect |
| `record` | `record [--failed-phase P] [--note T] <run-id> <hyp-id> <held\|violated\|not-reproducible\|aborted> [finding-ref]` | 0, 2 on bad arguments |
| `sanitize` | `sanitize [file]` prints redacted text; `sanitize --detect [file]` reports matching lines | 0, or 1 when `--detect` finds something |
| `lint-finding` | `lint-finding <finding.md>`: checks the frontmatter (`title`, `severity`, `run`), the six headings and redaction | 0 ok, 1 not |
| `sink` | `sink list-open [hyp-id]`, `sink create <hyp-id> <finding.md>`, `sink comment <ref> <body.md>`, `sink close <ref>` | 0, 2 bad arguments, 3 duplicate on create |
| `autorun` | `autorun --all` or `autorun <hyp-id>...`: runs reviewed hypotheses unattended on sandbox targets, compares each outcome with the previous one, writes `chaos/runs/autorun-<timestamp>.json`; never files findings. See `docs/continuous-runs.md`. | 0 nothing regressed, 1 regression or new violation, 2 incomplete or cleanup not confirmed |
| `watchdog` | started by `phase fault apply`; every `abort_interval` it runs the abort checks and stops the experiment when one fails; reverts the fault at duration expiry | |

### `phase`

| Command | Allowed in | Does |
|---|---|---|
| `start [--verify\|--auto] <hyp-id>` | no active run | validates the binding and hypothesis (both reviewed), records provenance, writes `runs/.active`, prints the run id |
| `up` | plan | `sandbox/up` (sandbox targets) |
| `guard` | any | `sandbox/guard`; required before inject, re-run before every fault |
| `confirm` | plan | records the user's confirmation of an existing target |
| `baseline` | plan, triage | runs the check with no fault active. In plan, inject needs it to pass. In triage (existing targets), a pass allows the repeat; a fail skips it and records `reproduction: skipped`. |
| `to <phase>` | forward only | plan, inject, observe, triage, report, cleanup. Inject needs a passed guard, a passed baseline and, for existing targets, confirmation. |
| `fault apply` | inject (once), triage (once more, after `reset` or a passing `baseline`) | checks the fault is `inactive`, re-runs guard, starts the watchdog, applies, then waits up to 10s for `status` to report `active`. If it never does: reverts and exits 3. One-off faults skip that assertion. |
| `fault revert` / `fault status` | any | |
| `check` | observe, triage; refused after an abort | waits until `wait` has passed since the fault was applied, runs the check under `check_timeout`, saves `check-<n>.out`, passes its exit code through (124 = timed out) |
| `recover` | observe, triage, fault reverted; refused after an abort | re-runs the check every 2s until it holds or `recovers_within` elapses; records `recovered` |
| `reset` | triage, sandbox targets, once | `down`, `up`, guard, baseline: a fresh instance for the repeat |
| `evidence` | observe, triage | `sandbox/evidence runs/<run>/evidence <fault applied at>` |
| `note <text>` | any | adds a note to the record |
| `end <outcome> [ref]` | any | reverts, confirms `inactive`, tears the sandbox down, writes the record; prints `cleanup confirmed: fault inactive` or `CLEANUP NOT CONFIRMED` |
| `abort [reason]` | any | same as `end` with outcome `aborted`; after an abort check stopped the experiment, the note names the check and its output |
| `show` | any | prints the run state and `watchdog_deadline` |

## Examples

Run from a repo that has a reviewed binding and a reviewed hypothesis `demo-kill` (the plugin's `scripts/` on `PATH`):

```console
$ validate
$ pick
$ phase start demo-kill
$ phase up
$ phase guard
$ phase baseline
$ phase to inject
$ phase fault apply
$ phase show
$ phase to observe
$ phase fault status
$ phase evidence
$ phase fault revert
$ phase recover
$ phase note example run
$ phase to cleanup
$ phase end held
$ sanitize --detect chaos/target.md
```
