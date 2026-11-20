# Spec Delta

## ADDED Requirements

### Requirement: Fidelity notes
`chaos/target.md` frontmatter SHALL accept `fidelity`, a one-line note on how the target differs from production, which is copied into every run record and finding.

#### Scenario: Base image fallback
- **WHEN** the sandbox is built on a public base image instead of the production one and `fidelity` says so
- **THEN** each run record and published finding includes that note

### Requirement: Guard proves the probed endpoint
When a hypothesis check probes a network endpoint, `/chaos:profile` SHALL draft a guard that proves the instance answering on that endpoint is the declared target, not only that a container or host with the right name exists.

#### Scenario: Port served by something else
- **WHEN** the declared containers exist but another process answers on the probed port
- **THEN** the guard drafted by profile fails

### Requirement: Unbuildable production image
When the production image or environment cannot be reproduced, `/chaos:profile` SHALL ask the user whether to stop or to fall back, and on a fallback SHALL record the difference as a fidelity note.

#### Scenario: Private registry refuses the pull
- **WHEN** the production base image needs credentials the session does not have
- **THEN** profile asks the user, and if they choose a fallback, `target.md` gets a `fidelity` note naming it

## MODIFIED Requirements

### Requirement: Bindings are drafted, then reviewed
`/chaos:profile` SHALL draft `target.md` and the sandbox executables from the repository's contents and SHALL NOT run any fault until the user has accepted the drafted binding, recorded by `validate --stamp binding` as a hash in `chaos/.review` without changing `target.md`.

#### Scenario: Profile a repository
- **WHEN** the user runs `/chaos:profile` in a repository with a Dockerfile
- **THEN** the plugin writes a draft `target.md` and sandbox executables and asks the user to review them before any run

#### Scenario: Stamping leaves target.md alone
- **WHEN** the binding is stamped
- **THEN** only `chaos/.review` changes
