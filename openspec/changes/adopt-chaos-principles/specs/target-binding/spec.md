# Spec Delta

## ADDED Requirements

### Requirement: Target-level abort check
The binding SHALL accept an optional executable `chaos/sandbox/abort`, with the same contract as a hypothesis's `abort`, which applies to every hypothesis run against the target.

#### Scenario: Target-wide safety signal
- **WHEN** `chaos/sandbox/abort` exits non-zero during any hypothesis's fault
- **THEN** that experiment is stopped, whether or not the hypothesis has its own `abort`

#### Scenario: Part of the reviewed binding
- **WHEN** `chaos/sandbox/abort` is added or changed after the binding was stamped
- **THEN** runs refuse to start until the binding is reviewed and stamped again
