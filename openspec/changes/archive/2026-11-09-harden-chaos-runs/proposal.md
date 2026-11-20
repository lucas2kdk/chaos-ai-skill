# Proposal

## Why

The first real run, on the versions monitor, found a sev-1 bug, but it also showed where a run can mislead. A fault that silently does nothing is recorded as `held`. A target that is already unhealthy is reported as `violated`. The fault script, the most dangerous file, is never reviewed. Recovery and timing have no place in the format. The triage retest proves nothing for faults that don't heal. A plugin meant for more important systems has to close these gaps first.

## What Changes

- Before inject, a run checks the steady state; if it is already violated, the run aborts as `aborted` with "baseline violated".
- After `fault apply`, `fault status` must report `active`, otherwise the fault is reverted and the run aborts with "fault did not take effect". Hypotheses can declare a one-off fault, which is exempt and recorded as such. The existing rule that a fault must be `inactive` before apply is added to the specs.
- Hypotheses are reviewed and stamped like the binding. Review stamps move out of `target.md` into `chaos/.review`. **BREAKING:** existing bindings must be re-stamped once.
- New hypothesis frontmatter: `wait` and `check_timeout` (validated to fit inside `duration`), `recovers_within` (recovery is measured after revert) and `one_off`. `phase check` waits by itself; the skill no longer sleeps.
- A new severity `sev-0`: the target does not recover after the fault ends. Findings state whether and when the target recovered.
- `record.json` gains provenance: git commit and dirty flag, binding and hypothesis hashes, fidelity notes, guard output, a summary of each check, and fault status after apply and after revert. Published findings end with a generated `## Provenance` section.
- The triage retest becomes independent. Sandboxes are torn down and brought up again before the repeat. Existing targets that have not recovered skip the repeat, and the finding says so.
- The guardrail hook ignores shell metacharacters inside quotes.
- `phase` prints explicit confirmation lines, `phase show` shows the watchdog deadline, and `validate` lists what it checked.
- Profile fixes: hypothesis helpers live in `chaos/lib/` (outside the reviewed binding); guards must prove the endpoint the check probes; the skill says what to do when the production image cannot be built (fall back and record a fidelity note, or ask).
- `sink create` takes title and severity from the finding's frontmatter instead of command-line arguments. **BREAKING** for the sink CLI.
- Small fixes: explore's empty focus text, and `grep -e` guidance in the run skill and guardrails doc.

Out of scope: a Docker socket proxy that enforces the blast radius, a canary abort condition, a dry-run mode for existing targets, and persisting explore candidates.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `run-pipeline`: baseline check, fault-effect assertion, inactive-before-apply, independent retest, recovery measurement, provenance in the run record, confirmation output.
- `hypothesis-format`: timing, recovery and one-off fields; hypothesis review stamp; helpers outside the binding.
- `target-binding`: review stamp in `chaos/.review`, fidelity notes, guard proves the probed endpoint, image-fallback guidance.
- `finding-report`: `sev-0`, recovery result, generated provenance section, title and severity from frontmatter.
- `phase-guardrails`: quote-aware command checks, and the new phase commands in the allowlist.

## Impact

- Scripts: `phase`, `validate`, `record`, `lint-finding`, `sink`, `sink-local`, `sink-github`, `lib.sh`; hook `hooks/guardrail`.
- Skills: `run`, `verify`, `profile`, `hypothesize`, `explore`.
- Docs: `contracts.md`, `guardrails.md`, `finding-format.md`, templates.
- Examples: both bindings re-stamped into `chaos/.review`; the Docker `api-crash` hypothesis declared `one_off`.
- Repos already using the plugin (versions-monitor) need `validate --stamp` once for the binding and each hypothesis.
