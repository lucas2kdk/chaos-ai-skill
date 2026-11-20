# finding-report Specification

## Purpose
Defines what a chaos finding contains and where it goes, so a separate fixer, human or agent, can reproduce the bug and verify a fix with no other context.

## Requirements

### Requirement: Finding sections
A finding body written for a run SHALL contain exactly these level-2 headings, in order: Hypothesis, Expected, Observed, Reproduction, Evidence, Suspected cause (unverified hypothesis); the published finding additionally ends with the generated Provenance section.

#### Scenario: Well-formed finding
- **WHEN** the report phase writes a finding
- **THEN** the body has exactly those six headings in that order and no other level-2 headings

### Requirement: Reproduction is executable
The Reproduction section SHALL include the fault, the steps to apply it, and the check command, so the bug can be re-run from the finding alone.

#### Scenario: Fixer reproduces
- **WHEN** a fixer applies the fault and runs the check from the finding against the declared target
- **THEN** the check exits non-zero while the bug is present

### Requirement: Severity
Each finding SHALL carry one severity: `sev-0` if the target does not recover after the fault ends without intervention, `sev-1` if the failure lasts as long as the fault does, `sev-2` if it recovers on its own after a one-off fault, `sev-3` for minor degradation.

#### Scenario: Self-recovering failure
- **WHEN** the target fails during a one-off fault and recovers without intervention
- **THEN** the finding is `sev-2`

#### Scenario: Stuck after the fault
- **WHEN** the run recorded `recovered: false`
- **THEN** the finding is `sev-0`

### Requirement: Suspected cause is marked unverified
A suspected cause SHALL be optional and SHALL be labelled as unverified; verified facts SHALL appear under Observed or Evidence.

#### Scenario: Cause guessed from logs
- **WHEN** triage infers a likely cause it has not verified
- **THEN** it appears only under the Suspected cause heading

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

### Requirement: No credentials in findings
The report phase SHALL NOT publish a finding that still contains a credential-shaped string after sanitising; it SHALL stop and tell the user.

#### Scenario: Credential slips through
- **WHEN** a finding body matches a credential pattern
- **THEN** nothing is published and the user is told which section matched

### Requirement: Verify a fix
`/chaos:verify <finding>` SHALL apply the finding's fault to the declared target, run its check, revert the fault, and report fixed when the check exits 0 and not fixed otherwise.

#### Scenario: Fix works
- **WHEN** the check exits 0 while the fault is active
- **THEN** verify reports the finding as fixed

#### Scenario: Bug remains
- **WHEN** the check exits non-zero while the fault is active
- **THEN** verify reports not fixed and includes the check output

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
