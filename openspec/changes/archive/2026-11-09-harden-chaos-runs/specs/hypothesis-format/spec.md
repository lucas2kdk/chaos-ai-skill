# Spec Delta

## ADDED Requirements

### Requirement: Timing fields
`hypothesis.md` frontmatter SHALL accept `wait` (time between fault apply and check, default 5s) and `check_timeout` (longest the check may run, default 60s), and validation SHALL reject a hypothesis where `wait + check_timeout + 10s` exceeds `duration`.

#### Scenario: Observation would outlast the fault
- **WHEN** a hypothesis has `duration: 60s`, `wait: 5s` and `check_timeout: 50s`
- **THEN** validation fails and says the observation does not fit inside the fault

#### Scenario: Check waits on its own
- **WHEN** `phase check` runs 2s after the fault was applied and `wait` is 5s
- **THEN** it waits 3s more before running the check

### Requirement: Recovery expectation
`hypothesis.md` frontmatter SHALL accept `recovers_within`, the time after revert within which the steady state must hold again, defaulting to `wait + check_timeout`.

#### Scenario: Recovery window declared
- **WHEN** a hypothesis declares `recovers_within: 30s`
- **THEN** the run measures recovery for at most 30s after revert

### Requirement: One-off faults
`hypothesis.md` frontmatter SHALL accept `one_off: true` for faults that are a single event with nothing to revert, such as killing a process.

#### Scenario: One-off kill
- **WHEN** a hypothesis that kills a process declares `one_off: true`
- **THEN** its `fault status` may always report `inactive` and the run does not treat that as a fault without effect

### Requirement: Hypotheses are stamped after review
A hypothesis SHALL be runnable only after the user approved it and `validate --stamp hypothesis <id>` recorded a hash of its `hypothesis.md`, `fault` and `check` in `chaos/.review`.

#### Scenario: Fault edited after approval
- **WHEN** `fault` changes after the hypothesis was stamped
- **THEN** `phase start` refuses the hypothesis until it is reviewed and stamped again

#### Scenario: Never stamped
- **WHEN** a hypothesis has no stamp in `chaos/.review`
- **THEN** validation reports it as not reviewed and `pick` skips it

### Requirement: Helpers live outside the binding
Shared helpers used by hypothesis checks and faults SHALL live in `chaos/lib/`, which is not part of the reviewed binding.

#### Scenario: New helper for a new hypothesis
- **WHEN** `/chaos:hypothesize` adds a helper function
- **THEN** it is written to `chaos/lib/` and the binding's stamp stays valid
