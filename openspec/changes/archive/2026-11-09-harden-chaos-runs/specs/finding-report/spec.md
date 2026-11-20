# Spec Delta

## ADDED Requirements

### Requirement: Recovery result in findings
A published finding SHALL state whether the target recovered after the fault was reverted, and how long recovery took or how long it was observed without recovering.

#### Scenario: Did not recover
- **WHEN** the run recorded `recovered: false` after a 60s window
- **THEN** the finding says the target had not recovered 60s after revert

### Requirement: Generated provenance
The sink SHALL append a `## Provenance` section to every published finding, generated from the run record: run id, commit and dirty flag, binding and hypothesis hashes, fidelity note and recovery result.

#### Scenario: Agent does not write provenance
- **WHEN** a finding body without a Provenance section is published
- **THEN** the published finding ends with a Provenance section built from `record.json`

## MODIFIED Requirements

### Requirement: Finding sections
A finding body written for a run SHALL contain exactly these level-2 headings, in order: Hypothesis, Expected, Observed, Reproduction, Evidence, Suspected cause (unverified hypothesis); the published finding additionally ends with the generated Provenance section.

#### Scenario: Well-formed finding
- **WHEN** the report phase writes a finding
- **THEN** the body has exactly those six headings in that order and no other level-2 headings

### Requirement: Severity
Each finding SHALL carry one severity: `sev-0` if the target does not recover after the fault ends without intervention, `sev-1` if the failure lasts as long as the fault does, `sev-2` if it recovers on its own after a one-off fault, `sev-3` for minor degradation.

#### Scenario: Self-recovering failure
- **WHEN** the target fails during a one-off fault and recovers without intervention
- **THEN** the finding is `sev-2`

#### Scenario: Stuck after the fault
- **WHEN** the run recorded `recovered: false`
- **THEN** the finding is `sev-0`

### Requirement: Report sinks
The report phase SHALL write findings to the sink set in `chaos/config.yaml`, supporting at least `local` (markdown files under `chaos/findings/`) and `github` (issues with a `chaos-found` label, a severity label and a hypothesis label), taking the title and severity from the finding's frontmatter.

#### Scenario: Local sink
- **WHEN** the sink is `local`
- **THEN** the finding is written to `chaos/findings/<hypothesis-id>.md` and no network call is made

#### Scenario: GitHub sink
- **WHEN** the sink is `github`
- **THEN** an issue is created, or a comment added to the open duplicate, with the three labels

#### Scenario: Missing title or severity
- **WHEN** the finding's frontmatter lacks `title` or a valid `severity`
- **THEN** nothing is published and the sink names the missing field
