# Spec Delta

## ADDED Requirements

### Requirement: Comparison and source in provenance
The generated Provenance section SHALL include the hypothesis `source` when declared, the control and experimental values with the tolerance for control-group hypotheses, and which abort check stopped the experiment when one did.

#### Scenario: Control-group finding
- **WHEN** a finding comes from a control-group run where experiment measured 70 against control 100 with tolerance 10%
- **THEN** its Provenance shows both values, the tolerance and the 30% difference

#### Scenario: Postmortem source
- **WHEN** the hypothesis declares `source`
- **THEN** the finding's Provenance names it
