# Spec Delta

## ADDED Requirements

### Requirement: Baseline before inject
Before the first fault is applied, a run SHALL run the hypothesis check against the target and abort if the steady state is already violated.

#### Scenario: Healthy baseline
- **WHEN** the baseline check exits 0
- **THEN** the run may move to inject, and the record notes the baseline passed

#### Scenario: Target already unhealthy
- **WHEN** the baseline check exits non-zero
- **THEN** no fault is applied and the run is recorded as `aborted` with the note "baseline violated"

### Requirement: Fault must be inactive before apply
`phase fault apply` SHALL refuse to apply a fault while `fault status` reports anything other than `inactive`.

#### Scenario: Fault left over from an earlier run
- **WHEN** `fault status` reports `active` before apply
- **THEN** apply is refused with a message to revert and check the target, and nothing is applied

### Requirement: Fault must take effect
After applying a fault that is not declared one-off, the run SHALL confirm that `fault status` reports `active`; otherwise it SHALL revert and abort.

#### Scenario: No-op fault
- **WHEN** `fault apply` exits 0 but `fault status` still reports `inactive`
- **THEN** the fault is reverted and the run is recorded as `aborted` with the note "fault did not take effect"

#### Scenario: One-off fault
- **WHEN** the hypothesis declares `one_off: true`
- **THEN** the status assertion is skipped, the apply exit code decides, and the record notes "one-off fault; effect not asserted"

### Requirement: Recovery is measured
After the fault is reverted, a run SHALL re-run the check until it passes or `recovers_within` elapses, and record whether and when the target recovered.

#### Scenario: Target recovers
- **WHEN** the check passes 20s after revert and `recovers_within` is 60s
- **THEN** the record shows `recovered: true` with a recovery time of about 20s

#### Scenario: Target stays broken
- **WHEN** the check still fails when `recovers_within` elapses
- **THEN** the record shows `recovered: false`

### Requirement: Explicit confirmations
`phase` SHALL print an explicit line when a fault is confirmed active, and when cleanup confirms the fault inactive or cannot confirm it.

#### Scenario: Cleanup confirmed
- **WHEN** `phase end` reverts and `fault status` reports `inactive`
- **THEN** the output includes "cleanup confirmed: fault inactive"

## MODIFIED Requirements

### Requirement: Reproduce once before reporting
Triage SHALL repeat the experiment once before anything is reported, from a fresh start: a sandbox target is torn down and brought up again, guarded and baseline-checked; an existing target is used only if it has recovered.

#### Scenario: Flaky result
- **WHEN** the repeat `check` exits 0
- **THEN** the run records `not-reproducible` and reports nothing

#### Scenario: Reproduced
- **WHEN** the repeat `check` exits non-zero
- **THEN** triage continues to dedupe and sanitise

#### Scenario: Existing target has not recovered
- **WHEN** the target is `existing` and its baseline still fails before the repeat
- **THEN** the repeat is skipped, the record notes "not independently reproduced", and triage continues

### Requirement: Run record
Each run SHALL write `chaos/runs/<run-id>/record.json` with the hypothesis id, start and end times, outcome (`held`, `violated`, `not-reproducible` or `aborted`), the finding reference when violated, and provenance: git commit and dirty flag, binding and hypothesis hashes, fidelity notes, guard output, each check's exit code and summary, fault status after apply and after revert, and the recovery result.

#### Scenario: Run finishes
- **WHEN** a run ends for any reason
- **THEN** `record.json` exists and its outcome is one of the four values

#### Scenario: Provenance recorded
- **WHEN** a run starts in a git repository with uncommitted changes
- **THEN** `record.json` holds the commit id and `dirty: true`, plus the binding and hypothesis hashes
