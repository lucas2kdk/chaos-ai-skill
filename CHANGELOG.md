# Changelog

Notable changes to the `chaos` plugin. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/). The reasoning behind each change is in [openspec/changes/](openspec/changes/).

## [0.2.0] - 2026-11-20

First public release.

### Added

- `scripts/autorun`: re-runs reviewed hypotheses with no agent, compares each outcome with the previous one, and exits non-zero on a regression. Sandbox targets only; it never files findings. See [docs/continuous-runs.md](docs/continuous-runs.md).
- Abort checks: an optional `abort` executable per target and per hypothesis, polled while a fault is active. When it fails, the fault is reverted at once.
- Control groups: `control: true` with a tolerance compares an experimental group against a control group measured at the same time.
- Baseline check before inject. A target that is already unhealthy aborts the run instead of being reported as `violated`.
- Fault-effect check. After `fault apply`, `fault status` must report `active`, or the run aborts. Hypotheses can declare `one_off` faults, which are exempt.
- Hypothesis frontmatter: `wait`, `check_timeout`, `recovers_within`, `one_off`, `control`, `source`.
- Severity `sev-0`: the target does not recover after the fault ends. Findings state whether and when the target recovered.
- Provenance in `record.json` and in published findings: git commit, binding and hypothesis hashes, fidelity notes, guard output, check summaries.

### Changed

- **Breaking:** hypotheses are reviewed and stamped like the binding, and stamps moved from `target.md` to `chaos/.review`. Re-stamp existing bindings and hypotheses with `validate --stamp`.
- **Breaking:** `sink create` takes title and severity from the finding's frontmatter, not from arguments.
- The triage repeat is independent: sandboxes are torn down and brought up again first.
- `phase check` waits by itself; the run skill no longer sleeps.
- Hypothesis helpers live in `chaos/lib/`, outside the reviewed binding.
- `/chaos:hypothesize` and `/chaos:explore` steer toward steady states users notice at the system boundary.

### Fixed

- The guardrail hook ignores shell metacharacters inside quotes.

## 0.1.0 - 2026-11-09

Not published.

### Added

- Claude Code plugin with `/chaos:explore`, `/chaos:profile`, `/chaos:hypothesize`, `/chaos:run` and `/chaos:verify`.
- A per-repo `chaos/` directory: config, target description, sandbox binding, hypotheses, run records.
- The target binding contract: `sandbox/up`, `down`, `guard`, `evidence`, and per hypothesis `fault` and `check`. See [docs/contracts.md](docs/contracts.md).
- Phase guardrails enforced by hooks: a per-phase command allowlist, the guard before every fault, a watchdog that reverts a fault at expiry, and a revert when the session stops.
- Findings with reproduction steps, redaction, and `local` and `github` sinks.
- Examples: Docker (two containers) and Kubernetes (kind, Online Boutique, Chaos Mesh).

[0.2.0]: https://github.com/lucas2kdk/chaos-ai-skill/releases/tag/v0.2.0