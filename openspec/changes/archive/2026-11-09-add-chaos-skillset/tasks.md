# Tasks

## 1. Plugin scaffold

- [x] 1.1 Create `.claude-plugin/plugin.json` (name `chaos`), empty `skills/`, `hooks/`, `scripts/`, `templates/`, `examples/`, `docs/`, plus README and LICENSE; verify `claude plugin validate .` (or loading the plugin locally with `--plugin-dir`) succeeds
- [x] 1.2 Add `templates/config.yaml` and `templates/target.md` with frontmatter (`kind`, `blast_radius`) and verify they parse with a YAML linter

## 2. Deterministic scripts

- [x] 2.1 Implement `scripts/validate` for binding and hypothesis structure (files present, executable, `duration` set, kebab-case id) with bats tests for valid, missing-file and missing-duration cases
- [x] 2.2 Port `record` with the four-value outcome enum and JSON output; verify with bats tests that an invalid outcome is rejected
- [x] 2.3 Port `sanitize` from chaos-ai and add a credential-detect mode that exits non-zero on a match; verify with fixture tests (token, password, email)
- [x] 2.4 Implement sinks `scripts/sink-local` and `scripts/sink-github` (`list-open`, `create`, `comment`); verify `local` with bats tests and `github` with a stubbed `gh`
- [x] 2.5 Implement `scripts/pick` (next valid hypothesis without an open finding via the sink) and verify with bats tests covering the all-covered case
- [x] 2.6 Document every script's arguments and exit codes in `docs/contracts.md` and verify each documented example runs as written

## 3. Phase state and guardrail hooks

- [x] 3.1 Implement `scripts/phase` (writes `chaos/runs/.active`, forward-only transitions, single triage re-inject, logs to the record) with bats tests for an allowed transition, a rejected backwards transition and the re-inject
- [x] 3.2 Implement `scripts/watchdog` that reverts a fault at `duration` expiry independently of the session; verify with a test fault that writes a marker file on revert
- [x] 3.3 Implement the PreToolUse hook for Bash/Write/Edit enforcing guard-first, inject-only-fault, read-only observe/triage, sink-only report, and the existing-target confirmation; verify with hook unit tests feeding sample tool-call JSON for each rule (allowed and blocked)
- [x] 3.4 Implement Stop/SessionEnd hooks that revert an active fault and record `aborted`; verify by ending a session mid-inject against the docker example
- [x] 3.5 Write `docs/guardrails.md` (layers, per-phase table, known gaps from design.md) and verify every rule in the hook has a row

## 4. Skills

- [x] 4.1 Write `skills/profile` (draft `target.md` and sandbox executables, guard-strength guidance, review before use) and verify on `examples/docker` that it produces a binding `validate` accepts
- [x] 4.2 Write `skills/hypothesize` (measurable steady state, blast-radius check, user approval) and verify it refuses a fault outside the blast radius
- [x] 4.3 Write `skills/run` driving the phases through the scripts, with existing-target confirmation, repro-once, dedupe, sanitise and cleanup; verify a held run and a violated run on `examples/docker`
- [x] 4.4 Write `skills/verify` and verify it reports not fixed on an open finding, then fixed after the example bug is patched
- [x] 4.5 Write `skills/explore` (read the repo, propose target and hypotheses, no writes) and verify it makes no file changes
- [x] 4.6 Document the five commands and the `chaos/` layout in README with a walkthrough, and verify the walkthrough runs end to end on `examples/docker`

## 5. Reference bindings

- [x] 5.1 Build `examples/docker`: a small HTTP service with one seeded resilience bug, plus a sandbox (labelled container) and two hypotheses; verify `validate` passes and one hypothesis reports `violated`
- [x] 5.2 Port chaos-ai to `examples/kubernetes` (kind, Online Boutique, Chaos Mesh, RBAC, three hypotheses with `fault` wrappers around the manifests); verify `rbac/verify.sh` and a `/chaos:run` of `cartservice-pod-kill` both work

## 6. Integration

- [x] 6.1 Install the plugin from a local marketplace into a fresh repo, run `/chaos:profile`, `/chaos:hypothesize` and `/chaos:run`, and verify `record.json`, the finding and that no fault remains active
- [x] 6.2 Run `openspec validate add-chaos-skillset --strict` and confirm it passes

## Workflow follow-up

- Archive the change once the plugin is published and the reference bindings are verified.
- Resolve the open questions in design.md (default sink, skills.sh) before publishing.
