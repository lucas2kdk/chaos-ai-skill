# Proposal

## Why

Basiri et al., "Chaos Engineering" (IEEE Software 33(3), 2016), the Netflix paper that defined the discipline, rests on four principles. The plugin follows two of them well: hypotheses around steady state, and realistic faults. It falls short on two more:
- It only runs when someone starts it, while the paper's fourth principle is that experiments run continuously, because confidence in a result fades as the system changes.
- It has no way to stop an experiment early when internal signals show harm.

Its before/after comparison also cannot tell a fault from normal drift on targets with real traffic. The paper solves that with a control group measured at the same time.

## What Changes

- **Continuous runs:** a new `autorun` script re-runs reviewed hypotheses without an agent: plan, inject, observe, recover, cleanup. It compares each outcome with the previous one and exits non-zero only on a new violation. It runs only sandbox targets, and never files findings. Docs show how to schedule it from cron and CI.
- **Abort condition:** an optional `abort` executable, per target (`chaos/sandbox/abort`) and per hypothesis, polled while a fault is active. When it fails, the fault is reverted at once, and the run records why it stopped.
- **Control group:** hypotheses can declare `control: true` with a tolerance. The check then measures a control group and an experimental group at the same time, and the steady state holds while the two stay within tolerance. The baseline check confirms the two groups agree before any fault.
- **Steady-state guidance:**
  - `/chaos:hypothesize` and `/chaos:explore` steer toward metrics users notice at the system boundary, faults drawn from postmortems, and non-failure inputs (load, config changes, malformed data). Internal metrics go to evidence and abort checks.
  - An optional `source:` field links a hypothesis to the incident or postmortem it came from, and is shown in findings.

Out of scope: combinations of several faults in one hypothesis, traffic-splitting infrastructure (the target must already be able to scope a fault to a group), and scheduling built into the plugin itself.

## Capabilities

### New Capabilities
- `continuous-runs`: unattended, repeated runs of reviewed hypotheses, how their outcomes are compared over time, and what such runs may and may not do.

### Modified Capabilities
- `hypothesis-format`: the `abort` executable, the control-group fields, the `source` field, and stamps that now cover `abort`.
- `target-binding`: an optional target-level `abort`.
- `run-pipeline`: abort polling while a fault is active, comparison against the control group, and baseline agreement between groups.
- `finding-report`: control and experiment values, and the hypothesis source, in findings.
- `phase-guardrails`: `autorun` is never callable during a run; an aborted experiment blocks further checks.

## Impact

- New: `scripts/autorun`, `docs/continuous-runs.md`.
- Changed: `scripts/phase`, `scripts/watchdog` (abort polling), `scripts/validate`, `scripts/lib.sh` (hash, provenance), `hooks/guardrail`, the skills (`hypothesize`, `explore`, `run`, `verify`, `profile`), templates, and `docs/contracts.md`, `guardrails.md` and `finding-format.md`.
- Existing hypotheses keep working: every new field and executable is optional. Adding `abort` to a hypothesis changes its hash, so it needs a new review and stamp.
