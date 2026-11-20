# Spec Delta

## Purpose

Defines the on-disk shape of a chaos hypothesis, so that any target, from a container to an Android app, can be tested and re-tested with the same three files.

## ADDED Requirements

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
