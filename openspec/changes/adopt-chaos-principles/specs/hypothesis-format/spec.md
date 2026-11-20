# Spec Delta

## ADDED Requirements

### Requirement: Abort check
A hypothesis SHALL accept an optional executable `abort` that exits 0 while it is safe to continue and non-zero when the experiment must stop, and SHALL NOT change the target.

#### Scenario: Internal signal says stop
- **WHEN** `abort` exits non-zero while the fault is active
- **THEN** the run stops the experiment as described in run-pipeline

#### Scenario: No abort check
- **WHEN** a hypothesis has no `abort` and the target has none
- **THEN** runs behave as before

### Requirement: Abort interval
`hypothesis.md` frontmatter SHALL accept `abort_interval` (default 5s), how often abort checks run while the fault is active.

#### Scenario: Custom interval
- **WHEN** a hypothesis declares `abort_interval: 2s`
- **THEN** abort checks run about every 2 seconds while its fault is active

### Requirement: Control-group checks
`hypothesis.md` frontmatter SHALL accept `control: true` with a `tolerance` (a percentage); such a hypothesis's `check` SHALL accept `control` or `experiment` as its argument and print a line `value: <number>` for that group.

#### Scenario: Missing tolerance
- **WHEN** a hypothesis declares `control: true` without `tolerance`
- **THEN** validation fails and names the missing field

#### Scenario: Group measured
- **WHEN** `check experiment` runs
- **THEN** it prints `value: <number>` for the experimental group and exits 0, or exits non-zero if it could not measure

### Requirement: Hypothesis source
`hypothesis.md` frontmatter SHALL accept `source`, a reference to the incident, postmortem or document the hypothesis came from.

#### Scenario: Postmortem-derived hypothesis
- **WHEN** a hypothesis declares `source: INC-1234 postmortem`
- **THEN** validation accepts it and findings from it show the source

### Requirement: Steady state at the system boundary
`/chaos:hypothesize` SHALL propose steady states that users would notice at the system boundary, and SHALL place internal signals such as CPU, queue depth or error logs in evidence or an abort check rather than in the hypothesis's check.

#### Scenario: Internal metric suggested as steady state
- **WHEN** the user asks for a hypothesis whose steady state is "CPU stays under 80%"
- **THEN** hypothesize proposes a user-visible steady state instead, and offers the CPU limit as an abort check

#### Scenario: Postmortem as input
- **WHEN** the user gives an incident or postmortem
- **THEN** hypothesize derives the fault from it and records it in `source`

## MODIFIED Requirements

### Requirement: Hypotheses are stamped after review
A hypothesis SHALL be runnable only after the user approved it and `validate --stamp hypothesis <id>` recorded a hash of its `hypothesis.md`, `fault`, `check` and, when present, `abort` in `chaos/.review`.

#### Scenario: Fault edited after approval
- **WHEN** `fault` changes after the hypothesis was stamped
- **THEN** `phase start` refuses the hypothesis until it is reviewed and stamped again

#### Scenario: Never stamped
- **WHEN** a hypothesis has no stamp in `chaos/.review`
- **THEN** validation reports it as not reviewed and `pick` skips it

#### Scenario: Abort check added after approval
- **WHEN** an `abort` executable is added to a stamped hypothesis
- **THEN** the hypothesis needs a new review and stamp before it runs
