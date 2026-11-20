# phase-guardrails Specification

## Purpose
Limits what each phase of a chaos run can do, enforced by the harness rather than by prompt wording, so a misbehaving or hijacked agent cannot exceed its phase.

## Requirements

### Requirement: Active phase is tracked
While a run is in progress, the plugin SHALL record the current run id and phase where its hooks can read it, and clear it when the run ends.

#### Scenario: Phase change
- **WHEN** the run moves from inject to observe
- **THEN** the recorded phase is `observe` before any observe command executes

### Requirement: Guard before target-touching commands
During a run, any command that can affect the target SHALL be blocked unless `guard` has passed in the same run.

#### Scenario: Guard not yet passed
- **WHEN** `fault apply` is attempted before `guard` has exited 0 in this run
- **THEN** the hook blocks the command

### Requirement: Inject phase is limited to the fault
In the inject phase, the only commands allowed to change the target SHALL be `fault apply`, `fault revert` and `fault status` of the selected hypothesis.

#### Scenario: Other write attempted
- **WHEN** a command other than the selected hypothesis's `fault` is run in the inject phase
- **THEN** the hook blocks it and explains which commands are allowed

### Requirement: Observe and triage are read-only
In the observe and triage phases, commands SHALL be limited to `check`, `evidence`, sanitising, and reading files and findings; the exceptions are triage's single repeat: tearing down and re-creating a sandbox target, its guard and baseline, and one more `fault apply` and `fault revert`.

#### Scenario: Write attempted while observing
- **WHEN** an observe-phase command tries to change the target or a file outside the run directory
- **THEN** the hook blocks it

### Requirement: Report phase reaches only the sink
In the report phase, external commands SHALL be limited to the configured report sink.

#### Scenario: Target access while reporting
- **WHEN** a report-phase command tries to reach the target
- **THEN** the hook blocks it

### Requirement: Fault reverted when the session ends
If a session stops while a fault is active, the plugin SHALL run `fault revert` for it and record the run as `aborted`.

#### Scenario: Session closed mid-run
- **WHEN** the user ends the session while the inject phase has an active fault
- **THEN** `fault revert` runs and `record.json` shows `aborted`

### Requirement: Guardrails are visible
The plugin SHALL document each guardrail and its known gaps, and a blocked command SHALL produce a message naming the rule that blocked it.

#### Scenario: Blocked command
- **WHEN** a hook blocks a command
- **THEN** the message names the phase and the rule

### Requirement: Quoted arguments are not shell syntax
During a run, the hook SHALL treat chaining, pipe, redirect and expansion characters as shell syntax only when they appear outside quotes.

#### Scenario: Pipe inside a quoted pattern
- **WHEN** triage runs `grep -E "fatal|TypeError" chaos/runs/<run-id>/evidence/monitor.log`
- **THEN** the hook allows it

#### Scenario: Real pipe
- **WHEN** a command contains `|` outside quotes
- **THEN** the hook blocks it

### Requirement: Fresh start is limited to triage
During a run, re-creating a sandbox SHALL be allowed only in triage, only for sandbox targets, and only once.

#### Scenario: Reset outside triage
- **WHEN** a sandbox reset is attempted in observe
- **THEN** it is refused
