# Tasks

## 1. Review stamps in chaos/.review

- [x] 1.1 Add hashing and `.review` read/write helpers to `scripts/lib.sh` (binding hash unchanged in scope, new hypothesis hash over hypothesis.md, fault, check) and verify with bats tests that editing `fault` changes the hypothesis hash and adding a file to `chaos/lib/` changes neither
- [x] 1.2 Change `validate`: `--stamp binding` and `--stamp hypothesis <id>` write `chaos/.review` without touching `target.md`; unreviewed or changed hypotheses fail unless `--draft`; the legacy `reviewed_hash` triggers the migration message; the `chaos/lib/` newer-than-stamp warning; each `ok` line lists what was checked. Verify with bats tests for each case
- [x] 1.3 Make `pick` skip unreviewed hypotheses and `phase start` refuse them; verify with bats tests

## 2. Hypothesis timing and recovery fields

- [x] 2.1 Validate `wait`, `check_timeout`, `recovers_within` and `one_off` (formats, defaults, `wait + check_timeout + 10s <= duration`) and verify with bats tests including the 60s/5s/50s rejection
- [x] 2.2 Update `templates/hypothesis/hypothesis.md` and `docs/contracts.md` with the new fields; verify the docs test still passes

## 3. Phase: baseline, effect, recovery, reset, provenance

- [x] 3.1 Add `phase baseline` and require a passed baseline for `to inject`; verify with bats tests for a healthy and an already-violated target
- [x] 3.2 After `fault apply`, poll `fault status` for `active` (skip for `one_off`), revert and exit 3 when it never activates, and print the confirmation line; verify with bats tests using a no-op fault and a one-off fault
- [x] 3.3 Make `phase check` wait until `fault_applied_at + wait` and enforce `check_timeout`, recording exit code and summary per check; verify with bats tests that time the wait and a hanging check
- [x] 3.4 Add `phase recover` (poll until pass or `recovers_within`, record `recovered` and `recovery_seconds`) and verify with bats tests for a recovering and a stuck fault
- [x] 3.5 Add `phase reset` (triage, sandbox only, once: down, up, guard, fresh counters) and `phase note`; verify with bats tests that reset outside triage, a second reset and reset on an existing target are refused
- [x] 3.6 Record provenance in `phase start` and the record (commit, dirty, hashes, fidelity, guard output, fault status after apply and revert, baseline, recovery); verify with bats tests in a temporary git repo
- [x] 3.7 Print `cleanup confirmed: fault inactive` or `CLEANUP NOT CONFIRMED` from `end`/`abort`, and the watchdog deadline from `show`; verify with bats tests
- [x] 3.8 Document the new phase commands and record fields in `docs/contracts.md` and keep its runnable examples passing (`tests/docs.bats`)

## 4. Findings

- [x] 4.1 Make `lint-finding` require frontmatter `title`, `severity` (`sev-0` to `sev-3`) and `run` with an existing record, and check the six headings after the frontmatter; verify with bats tests
- [x] 4.2 Change the `sink create <hyp> <body>` and `sink comment <ref> <body>` CLI for both sinks: read the frontmatter, strip it, append the generated `## Provenance` section from the run record, and support the `sev-0` label on GitHub; verify with bats tests, including the stubbed `gh`
- [x] 4.3 Update `docs/finding-format.md` (sev-0, frontmatter, recovery statement, generated provenance) and verify each documented field is checked by `lint-finding` or the sink

## 5. Guardrail hook

- [x] 5.1 Make the hook quote-aware (metacharacters outside quotes, `$` and backtick outside single quotes, newline anywhere) and verify with bats tests: quoted `|` allowed, a real pipe blocked, `"$HOME"` blocked, `'$HOME'` allowed
- [x] 5.2 Allowlist `baseline` (plan, triage), `recover` (observe, triage), `reset` (triage) and `note` (any) in the hook; verify with bats tests for allowed and refused phases
- [x] 5.3 Update `docs/guardrails.md` (new rows, quote rule, `grep -e` idiom, `chaos/lib/` gap) and verify the guardrails docs test passes

## 6. Skills

- [x] 6.1 Update `skills/run` and `skills/verify` for baseline, confirmations, no sleep, recover, the new triage flow, frontmatter findings and the new sink CLI; verify with a live headless `/chaos:run store-freeze` on a copy of the Docker example that ends `violated` with a finding carrying Provenance and `recovered`
- [x] 6.2 Update `skills/profile` (chaos/lib/, endpoint-proving guard, image fallback with fidelity, negative guard tests, `.review` stamping) and `skills/hypothesize` (timing fields, measuring check runtime, one_off, stamping after approval, liveness advice); verify `claude plugin validate .` passes
- [x] 6.3 Fix the explore empty-focus line and verify with `claude plugin validate .`

## 7. Examples and migration

- [x] 7.1 Migrate both examples: remove `reviewed_hash`, add timing fields, mark `api-crash` `one_off`, re-stamp binding and hypotheses into `chaos/.review`; verify `validate` passes in both
- [x] 7.2 Run the full suite (`bats tests/`, `claude plugin validate .`, `openspec validate harden-chaos-runs --strict`) and a live headless `/chaos:run api-crash` that ends `held` with `recovered: true`

## Workflow follow-up

- Tell the versions-monitor session that its binding and hypothesis need review and re-stamping into `chaos/.review`.
- Archive the change after review.
