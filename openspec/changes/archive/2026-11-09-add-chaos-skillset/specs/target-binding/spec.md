# Spec Delta

## Purpose

Defines how a repository declares the system it runs chaos experiments against, how far a fault may reach, and the executables that bring that target up, identify it, and collect evidence from it.

## ADDED Requirements

### Requirement: Target declaration
Each repository SHALL declare exactly one target in `chaos/target.md`, stating what the target is, whether it is a disposable sandbox or an existing instance, and its blast radius: what a fault may affect and what it must not.

#### Scenario: Missing declaration
- **WHEN** a run starts and `chaos/target.md` does not exist or lacks a target kind or blast radius
- **THEN** the run aborts before any fault is applied and tells the user to run `/chaos:profile`

#### Scenario: Declaration present
- **WHEN** `chaos/target.md` declares a target kind and blast radius
- **THEN** the run reads the declaration and continues to the guard

### Requirement: Guard proves target identity
The repository SHALL provide `chaos/sandbox/guard`, which exits 0 only when the live target matches the declaration in `chaos/target.md`, and non-zero otherwise.

#### Scenario: Guard passes
- **WHEN** `guard` exits 0
- **THEN** the run may proceed to fault injection

#### Scenario: Guard fails
- **WHEN** `guard` exits non-zero or cannot be executed
- **THEN** no fault is applied and the run is recorded as `aborted`

### Requirement: Sandbox lifecycle
For a target declared as a sandbox, the repository SHALL provide `chaos/sandbox/up` and `chaos/sandbox/down`, which create and destroy a disposable instance that `guard` can identify.

#### Scenario: Sandbox brought up
- **WHEN** `up` exits 0
- **THEN** `guard` exits 0 against the created instance

#### Scenario: Sandbox torn down
- **WHEN** `down` exits 0
- **THEN** the instance created by `up` no longer exists

### Requirement: Non-sandbox targets need confirmation
When the declared target is an existing instance rather than a sandbox, every run SHALL require explicit confirmation from the user that names the target and blast radius before the first fault.

#### Scenario: User confirms
- **WHEN** the user confirms the named target and blast radius
- **THEN** the run proceeds

#### Scenario: User declines or does not answer
- **WHEN** the user declines or does not confirm
- **THEN** no fault is applied and the run is recorded as `aborted`

### Requirement: Evidence collection
The repository SHALL provide `chaos/sandbox/evidence`, which writes logs and state for a given time window into a given directory without changing the target.

#### Scenario: Evidence gathered
- **WHEN** `evidence` is called with a run directory and a start time
- **THEN** timestamped files appear under that directory and the target is unchanged

### Requirement: Bindings are drafted, then reviewed
`/chaos:profile` SHALL draft `target.md` and the sandbox executables from the repository's contents and SHALL NOT run any fault until the user has accepted the drafted binding.

#### Scenario: Profile a repository
- **WHEN** the user runs `/chaos:profile` in a repository with a Dockerfile
- **THEN** the plugin writes a draft `target.md` and sandbox executables and asks the user to review them before any run
