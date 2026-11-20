# Design

## Context

See proposal.md for motivation. `scripts/phase` already owns every run step (baseline, guarded apply with effect assertion, timed check, evidence, revert, recover, end), and `scripts/watchdog` is a detached process started at `fault apply` that reverts at `duration`. Hypotheses are stamped over `hypothesis.md`, `fault` and `check`; the binding stamp covers everything in `chaos/sandbox/`. The paper's principles map onto these pieces, so this change adds little new machinery.

## Goals / Non-Goals

**Goals:**
- Unattended repeat runs that are no less safe than interactive ones.
- Experiments that stop themselves on internal harm signals, even when no one is watching.
- A comparison that separates fault effects from normal drift where a target can serve two groups.

**Non-Goals:**
- Combinations of several faults, traffic-splitting infrastructure, scheduling built into the plugin, and unattended runs against existing targets.

## Decisions

### `autorun` drives `phase`, without an agent

`scripts/autorun [--all | <id>...]` calls the same `phase` commands an interactive run uses, in the same order: `start --auto`, `up`, `guard`, `baseline`, `to inject`, `fault apply`, `to observe`, `check`, `evidence`, `fault revert`, `recover`, `to cleanup`, `end`. Because every guarantee lives in `phase` and the scripts (stamps, guard, baseline, effect assertion, watchdog, abort polling), an unattended run keeps them without an agent. Nothing reads untrusted log text and decides what to do, which is the main reason an agent is fenced in during interactive runs.

Alternative considered: headless `claude -p "/chaos:run"` on a schedule. Rejected: it puts an agent with a shell on an unattended loop, it costs tokens per run, and its results vary.

**No triage and no findings.** An unattended violation is recorded as `violated` with `finding: null` and `needs_triage: true`. `record` accepts a violated outcome without a finding reference only in mode `auto`. The summary names `/chaos:run <id>` as the next step; that interactive run does the fresh-start repeat, the sanitising and the finding.

**Previous outcome:** the newest earlier `record.json` for the same hypothesis whose outcome is `held` or `violated`, in mode `run` or `auto`. Aborted and verify runs are ignored. The change is `regression` (held, then violated), `fixed` (violated, then held), `new` (no previous outcome), `unchanged`, or `incomplete` (aborted now).

**Exit codes and locking:** 0 when nothing regressed; 1 for a regression or a new violation; 2 for a run that could not complete or a cleanup that was not confirmed, which also stops further hypotheses. `autorun` takes `mkdir chaos/runs/.autorun.lock` and refuses while `.active` exists, so two schedulers or a scheduler and a person never overlap. Existing targets are refused before anything starts.

**Summary:** `chaos/runs/autorun-<timestamp>.json`, plus one line per hypothesis on stdout for CI logs.

### Abort polling in the watchdog

The watchdog becomes a loop. Every `abort_interval` (default 5s), until `duration`:
- it runs `chaos/sandbox/abort` and the hypothesis's `abort`, if present, each under `timeout abort_interval`;
- a non-zero exit or a timeout means stop;
- on stop it reverts the fault, sets `aborted_by` (`target abort check` or `hypothesis abort check`) and `abort_output` (first line) in `.active` and the record, sets `fault_active` to false, and exits.

At `duration` it reverts, as today. For one-off faults the watchdog keeps polling, because the experiment still runs while the check observes. Reverting is a no-op there, but `aborted_by` is still set.

After an abort, `phase check`, `phase fault apply` and `phase recover` refuse with the reason; only `phase abort` (and `show`, `note`, `evidence`) remain useful. `phase abort` records outcome `aborted` with the abort reason as its note.

`abort` is added to the hypothesis hash only when present, so existing stamps stay valid until someone adds one. `chaos/sandbox/abort` is already covered by the binding hash.

### Control-group comparison inside `phase`

A hypothesis with `control: true` and `tolerance: N%` has a check that takes `control` or `experiment` and prints `value: <number>`. For such hypotheses, `phase check`, `baseline` and `recover`:
- run both groups concurrently (background both, wait);
- parse the last `value:` line of each;
- compute `diff = |experiment - control| / |control| * 100`, treating a control value of 0 as a failure to measure;
- pass when `diff <= tolerance`.

Each check event records `control`, `experiment` and `diff`; the summary line names all three. A group that fails to measure counts as violated, with "could not measure <group>".

The fault script is responsible for affecting only the experimental group, for example one of two replicas or requests carrying a header. Hypothesize guidance and the docs say so; the plugin does not route traffic.

Alternative considered: compare against historical baselines, as the paper's SPS trend line does. Rejected for now: it needs a metrics store, and a concurrent control works on any target that can be split.

### `source` and steady-state guidance

`source` is a free-text frontmatter field (a ticket, a postmortem link). It goes into the record's provenance and the generated Provenance section. Guidance changes are in the skills:
- `hypothesize` proposes boundary metrics, turns internal signals into abort checks, accepts postmortems as input and fills `source`.
- `explore` lists non-failure inputs (load, config, malformed data) and past incidents found in the repo (postmortem docs, incident references in commits) as fault sources.

### Guardrails

`autorun` is not on the hook's allowlist, so it is already blocked during a run; a test makes that explicit. Outside a run an agent may call it, but the skills present it as a scheduler tool.

## Risks / Trade-offs

- [Unattended runs break things at 3 a.m.] → sandbox targets only, every safety layer of `phase`, abort polling, the lock, exit 2 stops the batch, and the docs recommend running in working hours (as Netflix does with Chaos Monkey).
- [Abort checks that flap stop good experiments] → the record shows which check stopped it and its output, the interval is tunable, and abort checks are reviewed and stamped like faults.
- [Control groups need targets that can scope a fault to a group] → optional; hypotheses without `control` behave as before; examples and docs show a two-replica setup.
- [Comparing outcomes only between runs misses slow drift] → the summary keeps recovery times, so trends are visible; trend analysis is future work.
- [`record` allowing violated without a finding] → limited to mode `auto`, and `needs_triage` makes it visible.

## Migration Plan

Nothing to migrate: every field and executable is optional. Repos opt in per hypothesis. Adding an `abort` executable requires a new stamp.
