# Continuous runs

A chaos experiment that held last month says little about today: services change, configs change, dependencies change. `autorun` re-runs your reviewed hypotheses on a schedule and tells you when an outcome changes.

```
autorun --all               every valid, reviewed hypothesis, one after another
autorun store-freeze ...    only the ones named
```

It is the plugin's `scripts/autorun`. Run it from the repo, or anywhere below it.

## What it does

For each hypothesis, `autorun` runs the same `phase` steps as `/chaos:run`: sandbox up, guard, baseline, inject (the fault confirmed active), observe (check, evidence), revert, measure recovery, cleanup. Every safety layer applies: review stamps, the guard before each fault, the baseline, abort checks, the watchdog and confirmed cleanup.

What it does **not** do:
- It runs **no agent**. Nothing reads logs and decides what to do next.
- It **files no findings**. A violation is recorded with `needs_triage: true`; run `/chaos:run <id>` to repeat it from a fresh start, sanitise the evidence and file the finding.
- It **only runs sandbox targets**. An existing target needs a person to confirm every run, so `autorun` refuses it.
- It **never overlaps** another run. It refuses while `chaos/runs/.active` exists and holds `chaos/runs/.autorun.lock` while it works.

Unreviewed or invalid hypotheses are skipped, with the reason.

## Outcome changes

Each result is compared with the newest earlier `held` or `violated` result for the same hypothesis, from either `/chaos:run` or `autorun`:

| Change | Meaning |
|---|---|
| `regression` | held before, violated now |
| `fixed` | violated before, held now |
| `new` | no earlier result |
| `unchanged` | same outcome as before |
| `incomplete` | the run could not finish (baseline violated, fault did not take effect, an abort check stopped it, cleanup not confirmed) |
| `skipped` | not valid, not reviewed, or the batch stopped |

## Exit codes

| Exit | When | What to do |
|---|---|---|
| 0 | nothing regressed | nothing |
| 1 | a regression, or a violation with no earlier result | run `/chaos:run <id>` to triage and file the finding |
| 2 | a run could not complete, a cleanup was not confirmed (this also stops the batch), or `autorun` could not start | read the summary; if cleanup was not confirmed, check the target by hand |

Every invocation writes `chaos/runs/autorun-<timestamp>.json` with one entry per hypothesis: run id, outcome, previous outcome, change, recovery result and a note. It also prints one line per hypothesis, for CI logs.

## Scheduling

Run it in working hours, when someone can respond. Netflix runs Chaos Monkey only on weekdays for the same reason.

**cron**, weekdays at 10:00 (the plugin's `scripts/` on `PATH`, or use the full path):

```
0 10 * * 1-5  cd /srv/my-service && /path/to/chaos-plugin/scripts/autorun --all >> chaos/runs/autorun.log 2>&1
```

**GitHub Actions**, on a self-hosted runner that has Docker (and whatever else the sandbox needs):

```yaml
name: chaos
on:
  schedule:
    - cron: "0 10 * * 1-5"
  workflow_dispatch:
jobs:
  autorun:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - uses: actions/checkout@v4
        with: { repository: lucas2kdk/chaos-ai-skill, path: .chaos-plugin }
      - run: .chaos-plugin/scripts/autorun --all
      - if: always()
        uses: actions/upload-artifact@v4
        with: { name: chaos-runs, path: chaos/runs/ }
```

A failing job (exit 1 or 2) is the alert. The uploaded `chaos/runs/` holds the records and evidence for whoever triages.
