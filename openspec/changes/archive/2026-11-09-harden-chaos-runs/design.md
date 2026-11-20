# Design

## Context

See proposal.md for motivation. Run state lives in `chaos/runs/.active` and is driven only by `scripts/phase`. The hook `hooks/guardrail` allowlists commands per phase. Review stamps today are a `reviewed_hash` line in `target.md` that covers `target.md` and `chaos/sandbox/`. Hypotheses carry `id`, `steady_state`, `fault` and `duration`. The run skill sleeps 5s before `phase check`. Sinks take `<hyp> <sev> <title> <body>` as arguments.

## Goals / Non-Goals

**Goals:**
- No silent false results: a fault without effect, or an unhealthy baseline, aborts instead of producing `held` or `violated`.
- Everything that can break a target is reviewed and hash-checked.
- Timing, recovery and provenance are data, not prose.

**Non-Goals:**
- Enforcing the blast radius at the Docker socket, canary aborts, dry runs, persisted explore candidates.
- Changing the five-phase model or the sink set.

## Decisions

### Review stamps in `chaos/.review`

A flat file of `key: hash` lines: `binding: <hash>` and `hypothesis/<id>: <hash>`. The binding hash is unchanged in scope (`target.md` without any `reviewed_hash` line, plus every file in `chaos/sandbox/`). A hypothesis hash covers `hypothesis.md`, `fault` and `check`. `validate --stamp binding` and `validate --stamp hypothesis <id>` write the file. `validate` without `--draft` reports unreviewed or changed items, `pick` skips unreviewed hypotheses, and `phase start` refuses both.

Migration: when `target.md` still has a `reviewed_hash` and `chaos/.review` has no binding entry, `validate` explains that the stamp moved and to re-stamp after review. The old line is never trusted, since the hypotheses were never covered. Alternative considered: keep the stamp in each file's frontmatter. Rejected: it rewrites reviewed files, and other tools see that as an outside edit.

`chaos/lib/` is outside both hashes, so adding a helper does not invalidate a stamp. Because a helper can change what a stamped `fault` does, `validate` warns when a stamped hypothesis's `fault` or `check` sources a `chaos/lib/` file that is newer than the stamp. It warns rather than fails, and the docs say so.

### Hypothesis timing and recovery

New frontmatter, all optional, defaults in brackets: `wait` [5s], `check_timeout` [60s], `recovers_within` [wait + check_timeout], `one_off` [false]. `validate` enforces `wait + check_timeout + 10s <= duration`, so the observation ends before the watchdog fires.

`phase check` sleeps until `fault_applied_at + wait` when the fault is active, then runs the check under `timeout check_timeout`; a timeout counts as violated and is labelled so. The skill drops its `sleep 5`.

### New and changed `phase` commands

| Command | Phase | Does |
|---|---|---|
| `baseline` | plan; triage | runs the check with no fault active and records `baseline: pass/fail`. In plan, a fail is final: the skill aborts. `to inject` requires a passed baseline. |
| `fault apply` | as today | adds a status poll after apply: up to 10s for `active`, unless `one_off`. If it never reports `active`: revert, then exit 3 "fault did not take effect"; the skill aborts. Prints `fault active (confirmed)` or `one-off fault applied`. |
| `recover` | observe, triage, after revert | re-runs the check every 2s until it passes or `recovers_within` elapses; records `recovered` and `recovery_seconds`; exit 0 if recovered, 1 if not. |
| `reset` | triage, sandbox only, once | `down`, `up`, guard, and clears the applied-fault counters so the single repeat can run from a fresh instance. |
| `end` / `abort` | any | print `cleanup confirmed: fault inactive` or `CLEANUP NOT CONFIRMED`. |
| `show` | any | adds the watchdog deadline. |

Triage flow: `phase reset` (sandbox) or `phase baseline` (existing). If an existing target's baseline fails, the skill skips the repeat and calls `phase note "not independently reproduced"`; the record gets `reproduction: skipped`. Otherwise: `fault apply`, `check`, `fault revert`, `recover`.

### Provenance

`phase start` records `git rev-parse HEAD` and whether the tree is dirty (`git status --porcelain` is non-empty), or `null` outside git. It also records the binding hash, the hypothesis hash and the `target.md` `fidelity`. Guard events store guard's first output line. Each `check` event stores its exit code and a summary: the first `VIOLATED` line, else the last line, trimmed to 200 characters. Fault status after apply and after revert, `baseline`, `recovered` and `recovery_seconds` go into the record. `record` keeps all of this.

### Findings

The finding body gets frontmatter: `title`, `severity`, `run`. `lint-finding` checks it: `severity` must be `sev-0` to `sev-3`, and `run` must have a record. It also checks the six headings after the frontmatter. The new CLI is `sink create <hyp-id> <body.md>` and `sink comment <ref> <body.md>`. Each strips the frontmatter, appends a generated `## Provenance` section from `chaos/runs/<run>/record.json`, and then publishes. On GitHub, `sev-0` becomes a label like the others. The six-headings rule applies to what the agent writes; the published finding has seven.

### Quote-aware hook

The hook scans the command one character at a time, tracking single and double quotes:
- a newline anywhere is blocked;
- `; & | < >` are blocked outside quotes;
- `$` and backtick are blocked outside single quotes, since the shell expands them inside double quotes.

Words come from the existing `xargs` tokenisation. The phase allowlist gains `baseline` (plan, triage), `recover` (observe, triage), `reset` (triage) and `note` (any).

### Skills

- `run` and `verify`: baseline, the confirmations, recover, the new triage flow and frontmatter findings.
- `profile`: helpers in `chaos/lib/`, the "prove the endpoint the check probes" guard rule, image fallback (ask, then a `fidelity` note), negative guard tests (stale instance file, same-named object without the label).
- `hypothesize`: timing fields, timing the healthy check to choose `check_timeout`, `recovers_within`, `one_off`, approval, then `validate --stamp hypothesis <id>`; liveness advice for staleness checks.
- `explore`: drop the empty-focus line.
- `guardrails.md` and `run`: use `grep -e`.

## Risks / Trade-offs

- [BREAKING stamps: every existing repo must re-review] → `validate` explains the migration; the examples ship re-stamped; versions-monitor is told directly.
- [A fault whose `status` cannot observe the effect (a log-level change) fails "did not take effect"] → declare it `one_off`; the record notes the effect was not asserted.
- [`phase reset` doubles run time for slow sandboxes (kind)] → only in triage, only once; `keep_sandbox` does not skip it, because a stale instance is what made the old retest meaningless.
- [Recovery polling adds up to `recovers_within` per run] → defaults to the observation window; hypotheses can shorten it.
- [Helpers in `chaos/lib/` are unreviewed code that faults can call] → warning when a helper is newer than a stamp; documented as a known gap.

## Migration Plan

1. Ship scripts with the migration hint.
2. Re-stamp both examples (`chaos/.review`), remove `reviewed_hash` lines, mark `api-crash` `one_off`, and add timing fields.
3. Tell versions-monitor to review and re-stamp its binding and hypothesis.

Rollback: the old plugin version still reads `reviewed_hash` in `target.md`; keeping that line during the transition is harmless.
