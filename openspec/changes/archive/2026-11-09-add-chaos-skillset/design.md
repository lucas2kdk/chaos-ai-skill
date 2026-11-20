# Design

## Context

See proposal.md for motivation. The starting point is `../chaos-ai`: five subagents with `tools:` allowlists, per-role Kubernetes ServiceAccounts, about 290 lines of shell (`guard.sh`, `record.sh`, `sanitize.sh`, `pick-hypothesis.sh`, RBAC apply/verify), and hypotheses as `hypothesis.md` + `fault.yaml` + `check.sh`. Its safety came from the cluster (RBAC, namespace and fault-kind allowlists). Most targets this plugin aims at (a container, a game server, Ansible hosts, an Android emulator) have no such layer, so the safety has to move somewhere else.

## Goals / Non-Goals

**Goals:**
- One method and one set of file contracts that fit any target the agent can drive from a shell.
- Safety enforced by the harness (hooks and scripts), with prompts as a second layer, never the only one.
- Deterministic state handling (selection, records, validation, redaction) in scripts; skills stay thin.

**Non-Goals:**
- Shipping fault libraries or adapters per technology. The agent writes per-repo bindings.
- Fixing bugs, unattended or scheduled runs, multi-target runs.
- Runtimes other than Claude Code in this change. The file contracts stay runtime-neutral so another runtime can be added later.

## Decisions

### Plugin layout

```
.claude-plugin/plugin.json     name: "chaos" -> skills surface as /chaos:<name>
skills/{explore,profile,hypothesize,run,verify}/SKILL.md
hooks/hooks.json               PreToolUse (Bash, Write, Edit), Stop, SessionEnd
scripts/                       phase, record, sanitize, validate, pick, watchdog
templates/                     target.md, config.yaml, hypothesis skeletons
examples/kubernetes/           ported chaos-ai binding (kind + Online Boutique + Chaos Mesh)
examples/docker/               Dockerfile service binding
docs/                          method, contracts, guardrails, known gaps
```

Skills over separate commands: a skill is both a slash command and something the model can pick when it fits. Alternatives: plain `.claude/` files to copy (no hooks distribution), or an OpenSpec-style CLI (much more to build, and the state is small enough for scripts).

### Bindings are executables with exit codes

`chaos/sandbox/{up,down,guard,evidence}` and `chaos/hypotheses/<id>/{fault,check}` are executables in any language. The contract is only arguments and exit codes (spec: target-binding, hypothesis-format). That is what makes Docker, adb, Ansible and kubectl fit the same pipeline. chaos-ai's `fault.yaml` becomes a `fault` script that runs `kubectl apply|delete` on its manifest.

The fault's maximum duration lives in `hypothesis.md` frontmatter (`duration:`), so `validate` can check it without running anything.

### Per-repo `chaos/` directory

```
chaos/
  config.yaml      sink, default duration cap, keep-sandbox flag
  target.md        frontmatter: kind (sandbox|existing), blast_radius; prose: what the target is
  sandbox/         up, down, guard, evidence
  hypotheses/<id>/ hypothesis.md, fault, check
  runs/<run-id>/   record.json, evidence/, finding.md
  findings/        local sink output
```

It mirrors `openspec/`, so it is reviewable in PRs and readable without the plugin.

### Phases instead of subagents, enforced by hooks

`/chaos:run` is a single orchestrating skill. `scripts/phase` writes `chaos/runs/.active` (run id, hypothesis, phase, guard_passed, fault_active). A PreToolUse hook reads it and allows or blocks each Bash/Write/Edit call by phase, per spec phase-guardrails. Commands are matched on resolved paths of the binding executables and the plugin's own scripts, not on free text.

`phase` only moves forward (plan, inject, observe, triage, report, cleanup), except for the one triage re-inject, and logs every transition into the record. So the agent cannot jump back into inject after reading untrusted evidence.

Alternative: keep five plugin subagents with `tools:` allowlists. Rejected for now because allowlists cannot express "only this hypothesis's fault", and the hook is needed anyway. Subagents can be added later as defence in depth.

### Cleanup is enforced by the harness, not the prompt

- `fault apply` goes through `scripts/phase`, which starts `scripts/watchdog`: a detached timer that runs `fault revert` at `duration` expiry, even if the session dies.
- Stop/SessionEnd hooks run `fault revert` when `.active` shows `fault_active`.
- The run's own cleanup phase reverts and checks `fault status`.

### Non-sandbox targets

`target.md` with `kind: existing` makes `/chaos:run` ask the user (AskUserQuestion) to confirm the target name and blast radius before the first fault. The hook only allows `fault apply` when `.active` records the confirmation for this run id.

### Deterministic scripts own the state

These come from chaos-ai and get generalised: `pick` (next valid hypothesis without an open finding, sink-aware), `record` (writes `record.json`, outcome enum), `sanitize` (pattern redaction), and a new `validate` (hypothesis and binding structure, executability, `duration` present). Skills call scripts and read their JSON; they never write records by hand.

### Report sinks

A small sink interface in `scripts/sink-<name>`: `list-open <hyp-id>`, `create <body-file> <labels>`, `comment <ref> <body-file>`. This change ships `local` and `github`. Dedupe and pick use `list-open`, so they work the same with either sink.

### Reference bindings prove the contract

`examples/kubernetes` keeps chaos-ai's RBAC and kubeconfigs: there, Kubernetes credentials still stack on top of the hooks. `examples/docker` is the minimal non-Kubernetes case: `up` runs a labelled container, `guard` checks the label and container id, faults are `docker kill`/`pause`/`--memory`, and `check` probes the port.

## Risks / Trade-offs

- [The agent drives phase transitions, so a hijacked agent could call `phase` to switch] -> forward-only transitions, no inject after observe except the single triage re-inject, all logged in `record.json`.
- [The hook sees command strings; a binding script can do anything once allowed] -> bindings are reviewed by a human at profile time, and `validate` warns when a binding changes after review (hash stored in `target.md`).
- [`guard` is written by the agent and could be too weak] -> the profile skill includes guard-strength guidance per target kind (label/id/serial, never just a hostname), and docs show weak and strong examples.
- [Existing-target runs can harm real systems] -> declared blast radius, per-run confirmation, watchdog revert, duration cap in `config.yaml`.
- [Pattern-based redaction misses secrets] -> the `local` sink is the safe default for public repos, and a credential match blocks publishing.
- [Watchdog survives the session but not a host reboot] -> documented. Faults should be self-reverting where the tool supports it (Chaos Mesh duration, container restart policy).

## Migration Plan

New repository, so nothing to migrate. `../chaos-ai` stays as is. Its content is copied into `examples/kubernetes`, and it can later switch to installing the plugin.

## Open Questions

- Default sink in a fresh `config.yaml`: `local` (safer for public repos) or `github` (matches chaos-ai). Both are built either way, so only the template default changes.
- Whether to also publish the skills to skills.sh for other runtimes, without hooks and with weaker guarantees stated plainly.
