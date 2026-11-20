# Spec Delta

## ADDED Requirements

### Requirement: No autorun inside a run
During an interactive run, the hook SHALL block `autorun`, and `autorun` SHALL refuse to start while `chaos/runs/.active` exists.

#### Scenario: Agent tries autorun mid-run
- **WHEN** an agent calls `autorun` while a run is active
- **THEN** the hook blocks it

#### Scenario: Scheduler fires during an interactive run
- **WHEN** a scheduled `autorun` starts while someone is running `/chaos:run`
- **THEN** it exits 2 without touching the target and says a run is active

### Requirement: An aborted experiment stays stopped
After an abort check has stopped an experiment, `phase` SHALL refuse further `fault apply` and `check` in that run, so it can only be ended with `phase abort`.

#### Scenario: Check after abort
- **WHEN** the agent runs `phase check` after the abort poller reverted the fault
- **THEN** it is refused with the abort reason and the instruction to run `phase abort`
