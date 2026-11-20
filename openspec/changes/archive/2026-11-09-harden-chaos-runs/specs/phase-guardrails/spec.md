# Spec Delta

## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Observe and triage are read-only
In the observe and triage phases, commands SHALL be limited to `check`, `evidence`, sanitising, and reading files and findings; the exceptions are triage's single repeat: tearing down and re-creating a sandbox target, its guard and baseline, and one more `fault apply` and `fault revert`.

#### Scenario: Write attempted while observing
- **WHEN** an observe-phase command tries to change the target or a file outside the run directory
- **THEN** the hook blocks it
