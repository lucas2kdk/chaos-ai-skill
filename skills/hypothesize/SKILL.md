---
name: hypothesize
description: Write a chaos hypothesis for this repo - a measurable steady state, a time-boxed fault inside the declared blast radius, and a check that exits non-zero when the steady state is violated - then have the user approve it and stamp it. Use when the user wants to add, draft, review or suggest chaos experiments or hypotheses.
argument-hint: "[what to test]"
---

# /chaos:hypothesize

Turn an idea into `chaos/hypotheses/<id>/` with `hypothesis.md`, `fault` and `check`, and get it approved. The idea comes from the user ($ARGUMENTS) or from `/chaos:explore`. If $ARGUMENTS names a candidate from an earlier session you cannot see, ask the user to paste its description. Contracts: `${CLAUDE_PLUGIN_ROOT}/docs/contracts.md`.

## Before you start

- `${CLAUDE_PLUGIN_ROOT}/scripts/validate binding` must pass. If it does not, stop and suggest `/chaos:profile`.
- Read `chaos/target.md` (blast radius, steady state, identity, fidelity), `chaos/config.yaml` (`max_duration`), the existing hypotheses, the helpers in `chaos/lib/` and the open findings (`${CLAUDE_PLUGIN_ROOT}/scripts/sink list-open`). Do not duplicate a hypothesis.
- Check that the sandbox can express the fault. If it can't (for example, a hanging NFS mount on a sandbox with a plain volume), say what the binding would need and stop; extending the binding means `/chaos:profile` and a new review.

## Shape the hypothesis

A good hypothesis is one sentence a user would care about: "while X happens, Y still holds".

- **Steady state**: measurable, with a threshold, and something a user would notice at the system boundary: a page answers, a dashboard is fresh, an order goes through. "GET /items answers within 2s", not "the app works". Internal signals (CPU, memory, queue depth, error logs, restarts) are not the steady state: collect them as evidence, or use them in an abort check. If the user asks for an internal metric as the steady state, propose the user-visible one instead and offer theirs as an abort check.
- **Check liveness directly as well as the symptom.** A staleness threshold alone lets early samples pass while the thing that refreshes is already dead. If a process or loop produces the signal, also check that it is alive.
- **Fault**: one realistic event. Failures (a crash, a freeze, latency, a full disk, process death, airplane mode, an interrupted playbook) and also non-failure inputs (a spike in requests, a config change, a malformed response or input). Prefer faults that end on their own.
- **Past incidents are the best source.** If the user points at an incident, postmortem or ticket, derive the fault from what actually happened and put the reference in `source:`, so the finding links back to it.
- **Fault script**: `apply`, `revert` (safe to repeat) and `status`, which prints `active` while the fault is in effect and `inactive` otherwise. After apply, `phase` requires `status` to report `active`, so make `status` observe the real effect, not just "apply ran".
- **One-off events** (a kill with nothing to revert): set `one_off: true`; `status` may always print `inactive`, and the run records that the effect was not asserted.
- **Timing**: `wait` (time before the check), `check_timeout` (time the check may run), `duration`. Validation requires `wait + check_timeout + 10s <= duration` and `duration <= max_duration`. Keep `duration` as short as shows the effect.
- **Recovery**: `recovers_within`, how long after revert the steady state may take to hold again. If the interesting question is "does it come back?", say so in the body. The run measures it, and a target that does not recover becomes `sev-0`.
- **Check**: exits 0 when the steady state holds and non-zero when it does not; prints what it measured; never changes the target. Put shared helpers in `chaos/lib/`, never in `chaos/sandbox/` (that would invalidate the binding's review).
- **Abort check** (optional, `abort` next to the check): watches an internal harm signal while the fault is active, and exits non-zero to stop the experiment at once (for example "the api restarted more than twice", "error rate over 50%"). It runs every `abort_interval` without the agent. It must never change the target, and it is reviewed with the rest.
- **Control group** (optional): when the steady state drifts on its own, as with real traffic, set `control: true` and a `tolerance`. The check then takes `control` or `experiment` and prints `value: <number>`, and the fault must affect the experimental group only (one replica, one cohort). See the control-group section of `${CLAUDE_PLUGIN_ROOT}/docs/contracts.md`. A sandbox with no outside traffic rarely needs this.

**Blast radius:** compare the fault with `may_affect` and `must_not_affect`. If it would touch anything outside `may_affect`, or anything in `must_not_affect`, refuse to write it and explain which part of the blast radius it crosses. Suggest a version that stays inside, or tell the user that widening the blast radius means re-running `/chaos:profile` and a new review.

## Write, measure, get approval, stamp

1. Copy `${CLAUDE_PLUGIN_ROOT}/templates/hypothesis/` to `chaos/hypotheses/<id>/` and fill in all three files.
2. `${CLAUDE_PLUGIN_ROOT}/scripts/validate --draft hypothesis <id>` must pass.
3. Measure the **check** against a healthy target. For sandboxes: `chaos/sandbox/up`, then time `chaos/hypotheses/<id>/check` (expect exit 0), then `chaos/sandbox/down`. Set `check_timeout` to about twice the measured time, then validate again. Never run `fault` yourself. Faults only run inside `/chaos:run`, and the plugin's hook blocks running them directly.
4. Show the user the id, steady state, fault, timing, recovery window, how the check measures, and any abort check, control group or source. Point them at the files, especially `fault`, which is the script that breaks things. Ask whether they approve.
5. Only after an explicit yes: `${CLAUDE_PLUGIN_ROOT}/scripts/validate --stamp hypothesis <id>`. It records a hash of `hypothesis.md`, `fault`, `check` and `abort` in `chaos/.review`. Any later edit blocks runs until it is reviewed and stamped again.

Then suggest `/chaos:run <id>`. Once a hypothesis has been run interactively, it can run unattended on a schedule with `autorun` (see `${CLAUDE_PLUGIN_ROOT}/docs/continuous-runs.md`).

Existing hypotheses that `validate` reports as "not reviewed" or "changed since review" (for example, after upgrading the plugin) go through steps 4 and 5 too.

Never write hypotheses during a run. If you notice a gap while running one, propose it in the run summary instead.
