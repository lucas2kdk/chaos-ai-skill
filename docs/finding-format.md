# Finding format

A finding is the hand-off to whoever fixes the bug, human or agent. It must let them reproduce the failure and verify a fix with nothing else. `lint-finding` enforces the structure, and every sink runs it before publishing.

## Frontmatter

The finding written during a run starts with:

```
---
title: "store-freeze: GET /items hangs while the store is frozen"
severity: sev-1
run: 20261109T155159Z
---
```

| Key | Checked by | Meaning |
|---|---|---|
| `title` | `lint-finding` | the issue title, like `<hypothesis-id>: <symptom>` |
| `severity` | `lint-finding` | `sev-0` to `sev-3`, see below; becomes the GitHub label |
| `run` | `lint-finding` | the run id; its `record.json` must exist, and the sink builds the Provenance section from it |

The sink strips this frontmatter before publishing.

## Sections

Exactly these `##` headings, in this order, with no others:

1. `## Hypothesis`: the hypothesis id and the steady-state expectation that was tested.
2. `## Expected`: what should have happened under the fault.
3. `## Observed`: what happened (for control-group hypotheses, both groups' values and the difference), including the reproduction run and whether the target recovered after the fault was reverted (and how long it took, or how long it was watched without recovering). End with the severity line, e.g. `Severity: sev-2 (recovers on its own after a one-off fault)`. Verified facts go here or in Evidence.
4. `## Reproduction`, with three `###` subsections:
   - `### Fault`: what the fault does, and the contents of the hypothesis's `fault` script (or the manifest it applies).
   - `### Steps`: how to reproduce: bring the target up, run the guard, apply the fault, run the check, revert. Include `/chaos:verify <ref>` for plugin users.
   - `### Check command`: the hypothesis's `check`, which exits 0 when healthy and non-zero while the bug is present.
5. `## Evidence`: trimmed, timestamped excerpts from the relevant window only, already passed through `sanitize`. Never point at `chaos/runs/` paths, since a fixer may not have them.
6. `## Suspected cause (unverified hypothesis)`: optional. A guess, clearly marked as one. Write "None given." if there is nothing to say.

The sink then appends a seventh section, `## Provenance`, generated from the run record: run id, commit and whether the tree was dirty, binding and hypothesis hashes, the fidelity note, the baseline, the recovery result and whether the result was independently reproduced. When they apply, it also shows the hypothesis's `source` (the incident or postmortem it came from), the last control-group comparison (both values, the difference and the tolerance), and which abort check stopped the experiment early. Never write it yourself; `lint-finding` rejects a hand-written one.

## Severity

| Label | When |
|---|---|
| `sev-0` | The target does not recover after the fault ends: it stays broken until someone intervenes (the run recorded `recovered: false`). |
| `sev-1` | The user-facing failure lasts as long as the fault does. |
| `sev-2` | The failure recovers on its own after a one-off fault. |
| `sev-3` | Minor degradation. |

## Where findings go

Set in `chaos/config.yaml`:

- `sink: local` (default): `chaos/findings/<hypothesis-id>.md` with frontmatter `hypothesis`, `status: open|fixed`, `severity`, `title`, `run`, `created`. Later evidence is appended to `chaos/findings/<hypothesis-id>.comments.md`, with its own Provenance when the comment's frontmatter names a run.
- `sink: github`: an issue in the current `gh` repo with labels `chaos-found`, `sev-<n>` and `hyp:<hypothesis-id>`. A fixer finds work with `gh issue list --label chaos-found --state open`.

One open finding per hypothesis: a new violation of a hypothesis that already has one adds evidence to it.

## Verifying a fix

`/chaos:verify <ref>` applies the fault, runs the check while the fault is active, and reverts. Exit 0 means fixed; non-zero means the bug remains. Close a finding only after it reports fixed.
