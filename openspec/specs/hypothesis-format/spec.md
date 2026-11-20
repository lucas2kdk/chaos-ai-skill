# hypothesis-format Specification

## Purpose
Defines the on-disk shape of a chaos hypothesis, so that any target, from a container to an Android app, can be tested and re-tested with the same three files.

## Requirements

### Requirement: Hypothesis directory
Each hypothesis SHALL live in `chaos/hypotheses/<id>/` containing `hypothesis.md`, an executable `fault` and an executable `check`, where `<id>` is kebab-case and unique.

#### Scenario: Complete hypothesis
- **WHEN** a hypothesis directory contains all three files and both scripts are executable
- **THEN** it is eligible to be picked for a run

#### Scenario: Incomplete hypothesis
- **WHEN** any of the three files is missing or a script is not executable
- **THEN** validation reports the hypothesis as invalid and it is never picked

### Requirement: Steady state statement
`hypothesis.md` SHALL state the steady state as an observable, measurable expectation, and name the fault applied.

#### Scenario: Measurable steady state
- **WHEN** a hypothesis is drafted by `/chaos:hypothesize`
- **THEN** its steady state names what is measured and the threshold, for example "server answers a status ping within 2s"

### Requirement: Check exit semantics
`check` SHALL exit 0 when the steady state holds and non-zero when it is violated, and SHALL NOT change the target.

#### Scenario: Healthy target
- **WHEN** `check` runs against a target in steady state
- **THEN** it exits 0

#### Scenario: Violated steady state
- **WHEN** `check` runs while the steady state is violated
- **THEN** it exits non-zero and prints the failing observations

### Requirement: Time-boxed, reversible fault
`fault` SHALL accept `apply`, `revert` and `status`, SHALL declare a maximum duration after which the fault ends on its own or is reverted, and `revert` SHALL be safe to call repeatedly.

#### Scenario: Fault without a duration
- **WHEN** validation finds a `fault` that declares no maximum duration
- **THEN** the hypothesis is invalid

#### Scenario: Repeated revert
- **WHEN** `fault revert` is called twice
- **THEN** both calls exit 0 and `fault status` reports the fault inactive

### Requirement: Fault stays within the blast radius
A hypothesis's fault SHALL only affect what the declared blast radius allows.

#### Scenario: Fault outside the blast radius
- **WHEN** `/chaos:hypothesize` is asked for a fault that would affect something the blast radius excludes
- **THEN** it refuses to write the hypothesis and explains why

### Requirement: Hypotheses enter by review
New hypotheses SHALL be written only by `/chaos:hypothesize` with the user's approval, never during a run.

#### Scenario: Gap noticed during a run
- **WHEN** a run notices a missing hypothesis
- **THEN** it proposes it in the run summary and does not create any files under `chaos/hypotheses/`

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
