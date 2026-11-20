# Spec Delta

## Purpose

Lets reviewed chaos experiments run again and again without a person or an agent present, so confidence in their results keeps up with a changing system.

## ADDED Requirements

### Requirement: Unattended runs
`autorun` SHALL run reviewed hypotheses through plan, inject, observe, recovery and cleanup using only the plugin's scripts, with no agent and no prompts, recording each run like an interactive one with mode `auto`.

#### Scenario: Run every hypothesis
- **WHEN** `autorun --all` runs in a repository with two reviewed hypotheses
- **THEN** each is run once, in turn, and each gets a `record.json` with mode `auto`

#### Scenario: Run one hypothesis
- **WHEN** `autorun store-freeze` runs
- **THEN** only that hypothesis is run

### Requirement: Sandbox targets only
`autorun` SHALL refuse targets declared `existing`, because those need a person's confirmation on every run.

#### Scenario: Existing target
- **WHEN** `autorun` runs in a repository whose target is `kind: existing`
- **THEN** it exits non-zero without starting a run and explains why

### Requirement: Unreviewed hypotheses are skipped
`autorun` SHALL skip any hypothesis that is invalid or not reviewed, and say which and why.

#### Scenario: Hypothesis edited after review
- **WHEN** a hypothesis's `fault` changed since it was stamped
- **THEN** `autorun` skips it with the reason and runs the others

### Requirement: Outcome changes are reported
After each run, `autorun` SHALL compare the outcome with the previous outcome of the same hypothesis and report regressions (held before, violated now), fixes (violated before, held now) and unchanged results.

#### Scenario: Regression
- **WHEN** a hypothesis that held last time is violated now
- **THEN** `autorun` reports it as a regression, and its exit status is 1

#### Scenario: Nothing changed
- **WHEN** every outcome equals the previous one
- **THEN** `autorun` exits 0

### Requirement: Exit status for schedulers
`autorun` SHALL exit 0 when nothing regressed, 1 when at least one hypothesis regressed or was violated with no earlier result, and 2 when a run could not complete or cleanup was not confirmed.

#### Scenario: Cleanup not confirmed
- **WHEN** a fault does not report inactive after cleanup
- **THEN** `autorun` stops running further hypotheses and exits 2

### Requirement: No findings without triage
`autorun` SHALL NOT publish findings; a violation is reported as needing triage with `/chaos:run <id>`.

#### Scenario: New violation
- **WHEN** an unattended run is violated
- **THEN** no sink is called and the summary names the hypothesis and the command to triage it

### Requirement: Machine-readable summary
`autorun` SHALL write a summary of each invocation to `chaos/runs/autorun-<timestamp>.json`, listing each hypothesis with its run id, outcome, previous outcome, change and recovery result.

#### Scenario: Summary written
- **WHEN** `autorun --all` finishes
- **THEN** the summary file exists and has one entry per hypothesis, including skipped ones with their reason
