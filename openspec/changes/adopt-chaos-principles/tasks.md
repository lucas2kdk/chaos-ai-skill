# Tasks

## 1. Hypothesis fields

- [x] 1.1 Validate the new frontmatter (`abort_interval`, `control` with required `tolerance` like `10%`, `source`) and require `abort` to be executable when present; verify with bats tests for each valid and invalid case
- [x] 1.2 Include `abort` in the hypothesis hash only when present, so existing stamps stay valid; verify with bats tests that adding `abort` invalidates the stamp and that a hypothesis without one keeps its hash
- [x] 1.3 Update `templates/hypothesis/` (optional `abort`, new fields as comments) and `docs/contracts.md`; verify `tests/docs.bats` passes

## 2. Abort polling

- [x] 2.1 Turn the watchdog into a poller: run the target and hypothesis abort checks every `abort_interval` under a timeout, revert and record `aborted_by` and `abort_output` on failure, revert at `duration` as before, and keep polling for one-off faults; verify with bats tests for a target abort, a hypothesis abort, a hanging abort check and a one-off fault
- [x] 2.2 Make `phase check`, `fault apply` and `recover` refuse after an abort, and have `phase abort` record the abort reason; verify with bats tests
- [x] 2.3 Document abort checks in `docs/contracts.md` and `docs/guardrails.md` and verify the docs tests pass

## 3. Control-group comparison

- [x] 3.1 Make `phase check`, `baseline` and `recover` run both groups concurrently for `control: true`, parse `value:`, compare against `tolerance` and record control, experiment and diff; verify with bats tests for within tolerance, outside tolerance, a failed measurement and a zero control value
- [x] 3.2 Make the baseline fail when the groups disagree before the fault; verify with a bats test
- [x] 3.3 Document the control-group contract in `docs/contracts.md` with a two-replica example and verify the docs tests pass

## 4. Provenance and findings

- [x] 4.1 Record `source`, the comparison values and `aborted_by` in `record.json` and the generated Provenance section; verify with bats tests on `provenance_md`
- [x] 4.2 Update `docs/finding-format.md` and verify the finding-format docs test passes

## 5. autorun

- [x] 5.1 Add `phase start --auto` (mode `auto`) and let `record` accept `violated` without a finding reference only in that mode, setting `needs_triage`; verify with bats tests
- [x] 5.2 Implement `scripts/autorun [--all | <id>...]`: the lock, refusing existing targets and active runs, skipping unreviewed hypotheses with reasons, and driving `phase` end to end; verify with bats tests on the fixture repo
- [x] 5.3 Compare with the previous outcome, write `chaos/runs/autorun-<timestamp>.json`, print one line per hypothesis, and set exit codes 0, 1 and 2; verify with bats tests for regression, fixed, new, unchanged and cleanup-not-confirmed
- [x] 5.4 Write `docs/continuous-runs.md` (cron and CI examples, exit codes, working-hours advice) and document `autorun` in `docs/contracts.md`; verify the docs tests pass, including a check that `autorun` is documented

## 6. Guardrails

- [x] 6.1 Add hook tests that `autorun` is blocked during a run, and add it to the guardrails table; verify the hook and docs tests pass

## 7. Skills

- [x] 7.1 Update `skills/hypothesize` (boundary metrics, internal signals as abort checks, postmortems and `source`, non-failure inputs, control groups) and `skills/explore` (non-failure inputs, past incidents as fault sources); verify `claude plugin validate .` passes
- [x] 7.2 Update `skills/run` and `skills/verify` (handling an abort, reading control-group output) and `skills/profile` (optional target abort check); verify `claude plugin validate .` passes
- [x] 7.3 Mention continuous runs in the README; verify the README links resolve to existing files

## 8. Examples and integration

- [x] 8.1 Give the Docker example a hypothesis-level abort check (stop if the api container restarts more than twice), re-stamp it, and verify `validate` passes
- [x] 8.2 Run `autorun --all` twice on a copy of the Docker example and verify it reports a new violation for `store-freeze` and exit 1 the first time, unchanged and exit 0 the second time, and leaves no containers running
- [x] 8.3 Run the full suite (`bats tests/`, `claude plugin validate .`, `openspec validate adopt-chaos-principles --strict`)

## Workflow follow-up

- Archive the change after review.
