# Spec Delta

## ADDED Requirements

### Requirement: Abort polling
While a fault is active, the run SHALL poll the target's and the hypothesis's abort checks every `abort_interval`, independently of the agent; when either exits non-zero, it SHALL revert the fault immediately and record which check stopped the experiment.

#### Scenario: Abort during observe
- **WHEN** the hypothesis's `abort` exits non-zero 10s after the fault was applied
- **THEN** the fault is reverted within one interval, the record shows `aborted_by: hypothesis abort check` with its output, and the run can only end as `aborted`

#### Scenario: Agent is slow
- **WHEN** no phase command runs for a minute while the fault is active
- **THEN** abort checks keep running on schedule

### Requirement: Control-group comparison
For a hypothesis with `control: true`, `phase check` SHALL measure the control and experimental groups at the same time, and treat the steady state as violated when the experimental value differs from the control value by more than `tolerance`.

#### Scenario: Within tolerance
- **WHEN** control measures 100 and experiment measures 95 with `tolerance: 10%`
- **THEN** the check passes and the record holds both values

#### Scenario: Outside tolerance
- **WHEN** control measures 100 and experiment measures 70 with `tolerance: 10%`
- **THEN** the check is violated and its summary names both values and the difference

### Requirement: Groups agree before the fault
For a hypothesis with `control: true`, the baseline SHALL pass only when the two groups are within `tolerance` of each other with no fault active.

#### Scenario: Noisy measurement
- **WHEN** the groups differ by 20% before any fault and `tolerance` is 10%
- **THEN** the baseline fails and the run cannot inject
