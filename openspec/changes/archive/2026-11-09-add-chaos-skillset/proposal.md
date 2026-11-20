# Proposal

## Why

The chaos-ai pipeline (plan, inject, observe, triage, report) finds real resilience bugs and files issues a fixer can act on, but it is hardwired to one kind cluster, Online Boutique, Chaos Mesh and five Claude Code subagents. The method and its contracts are generic; the bindings are not. Publishing it as a Claude Code plugin that works on any repo (a Dockerfile, a Minecraft server, Ansible config, an Android app) needs the bindings to come from the repo, not from the tool.

## What Changes

- A Claude Code plugin with commands `/chaos:explore`, `/chaos:profile`, `/chaos:hypothesize`, `/chaos:run` and `/chaos:verify`.
- A per-repo `chaos/` directory (like `openspec/`) holding `config.yaml`, `target.md`, sandbox scripts, hypotheses and run records.
- A target binding contract of four executables with fixed exit-code semantics: `sandbox` (`up|down|guard`), `check`, `fault` (`apply|revert|status`) and `evidence`. The agent drafts these per repo; a human reviews them.
- Targets are declared per repo in `target.md`, with a declared blast radius. A run proceeds only when `guard` proves the live target matches the declaration, and non-sandbox targets need explicit confirmation.
- The five role subagents collapse into phases of one run, with per-phase permissions enforced by plugin hooks instead of Kubernetes RBAC. A session-end hook reverts any active fault.
- The run outcomes, repro-once triage, dedupe, sanitising and the six-section finding format carry over from chaos-ai unchanged.
- Two reference bindings: the chaos-ai kind/Online Boutique setup, and one non-Kubernetes target (a Dockerfile service).

## Capabilities

### New Capabilities
- `target-binding`: how a repo declares its target and blast radius, and the `sandbox`/`guard`/`evidence` executable contract.
- `hypothesis-format`: the on-disk shape of a hypothesis (steady state, `fault`, `check`) and its validation.
- `run-pipeline`: the phases of one run, its outcomes, triage (repro once, dedupe, sanitise) and the always-cleanup rule.
- `phase-guardrails`: per-phase tool permissions, guard enforcement and fault revert, enforced by hooks.
- `finding-report`: the finding format, report sinks, and how a fixer verifies a fix.

### Modified Capabilities
- None.

## Impact

- New repository content: plugin manifest, skills/commands, hooks, shared scripts, docs and two example bindings.
- Depends on Claude Code plugin and hook support. Report sinks may depend on `gh` or other CLIs.
- Ports content from `../chaos-ai` (scripts, docs, issue format); that repo stays as is.
- Injecting faults into declared non-sandbox targets is a real-world risk that the guardrails must contain.
