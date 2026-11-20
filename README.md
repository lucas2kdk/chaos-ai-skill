# chaos

[![ci](https://github.com/lucas2kdk/chaos-ai-skill/actions/workflows/ci.yml/badge.svg)](https://github.com/lucas2kdk/chaos-ai-skill/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A Claude Code plugin for chaos experiments on any repo: a Dockerfile, a Kubernetes app, a Minecraft server, Ansible config, an Android app. You describe the target once. Claude writes steady-state hypotheses, injects time-boxed faults behind guardrails the harness enforces, and files findings that a fixer (human or agent) can reproduce and verify.

```
/chaos:explore      where could this break?                    (read-only)
/chaos:profile      describe the target: chaos/target.md + chaos/sandbox/   (you review it)
/chaos:hypothesize  write a hypothesis: steady state, fault, check          (you approve it)
/chaos:run          plan -> inject -> observe -> triage -> report, always clean up
/chaos:verify       re-run a finding's fault and check: fixed or not fixed

scripts/autorun     re-run reviewed hypotheses unattended (cron, CI) and report what changed
```

## Install

```
/plugin marketplace add lucas2kdk/chaos-ai-skill
/plugin install chaos@chaos-ai-skill
```

Needs `bash`, `jq` and whatever your target needs (Docker, kubectl, adb, ...). The GitHub sink also needs `gh`.

## How it works

Every repo gets a `chaos/` directory, much like `openspec/`:

```
chaos/
  config.yaml          sink (local | github), max fault duration, keep sandbox
  target.md            what the target is, sandbox or existing, blast radius, review stamp
  sandbox/             up, down, guard, evidence      <- the binding, written by /chaos:profile
  hypotheses/<id>/     hypothesis.md, fault, check    <- written by /chaos:hypothesize
  runs/<run-id>/       record.json, check output, evidence, finding
  findings/            findings, when sink is local
```

The plugin doesn't ship adapters for each technology. Each target binds through a handful of executables in any language, defined only by their arguments and exit codes:

| Executable | Contract |
|---|---|
| `sandbox/up`, `sandbox/down` | create / destroy a disposable instance |
| `sandbox/guard` | exit 0 only if the live target is the declared one |
| `sandbox/evidence <dir> <since>` | dump logs and state, read-only |
| `hypotheses/<id>/fault apply\|revert\|status` | a time-boxed, revertible fault |
| `hypotheses/<id>/check` | exit 0 = steady state holds, non-zero = violated |

So `docker pause`, `adb shell am kill`, an interrupted `ansible-playbook` and a Chaos Mesh manifest all fit the same pipeline. Full reference: [docs/contracts.md](docs/contracts.md).

## Walkthrough

Using the bundled [Docker example](examples/docker/): an api that calls a store with no timeout.

1. **Explore.** `/chaos:explore` reads the repo and lists candidate hypotheses: "a frozen store makes `/items` hang".
2. **Profile.** `/chaos:profile` writes `chaos/target.md` and `chaos/sandbox/{up,down,guard,evidence}`, tries them, and asks you to review. On your yes it stamps the binding. Any later edit blocks runs until you review again. (The example ships already reviewed.)
3. **Hypothesize.** `/chaos:hypothesize store freeze` proposes: steady state "`GET /items` answers 200 or 503 within 2s", fault "`docker pause` the store for 60s". It refuses faults outside the blast radius.
4. **Run.** `/chaos:run store-freeze` brings the sandbox up, guards, pauses the store, and runs the check: five requests hang. It re-applies the fault once to rule out flakiness, writes a sanitised finding with reproduction steps to `chaos/findings/store-freeze.md`, reverts, tears down and records `violated`.
5. **Fix and verify.** Add a 1s timeout and a 503 fallback to `app/api.py`, then `/chaos:verify chaos/findings/store-freeze.md` reports **fixed**: every request gets a 503 within about 1s.

Without Claude, the same run is a sequence of `phase` commands; see [examples/docker/README.md](examples/docker/README.md).

## Continuous runs

A result from last month says little about today. `autorun --all` re-runs every reviewed hypothesis with no agent and no prompts, compares each outcome with the previous one, and exits non-zero on a regression, so a cron job or a scheduled CI job can be the alarm. It only runs sandboxes and never files findings; a regression is triaged with `/chaos:run`. See [docs/continuous-runs.md](docs/continuous-runs.md).

Hypotheses can also carry an **abort check** that stops an experiment the moment an internal signal (restarts, error rate, queue depth) shows harm, and a **control group** that compares against untouched traffic measured at the same time. Both follow the principles in Basiri et al., ["Chaos Engineering"](https://arxiv.org/abs/1702.05843), IEEE Software 2016.

## Safety

A chaos run gives an agent a shell and permission to break things, so the limits don't rely on prompt wording:

- **Reviewed binding:** runs refuse to start unless `target.md` and `chaos/sandbox/` match what you approved.
- **Guard:** checked before inject and again right before every fault.
- **Existing targets:** if you point it at an instance you already run, every run raises a permission prompt naming the target and blast radius.
- **Time box:** each fault declares a duration (capped by `max_duration`). A watchdog reverts it at expiry even if the session dies, and stopping Claude reverts it too.
- **Phase allowlist:** a PreToolUse hook lets each phase run only what it needs. Observing can't inject; reporting can't touch the target. Phases only move forward.
- **Redaction:** evidence is sanitised, and sinks refuse anything that still looks like a credential.

The model and its known gaps are in [docs/guardrails.md](docs/guardrails.md). Read the gaps before pointing this at anything you care about.

## Examples

- [`examples/docker`](examples/docker/): two containers and a seeded missing-timeout bug. One hypothesis holds, one is violated.
- [`examples/kubernetes`](examples/kubernetes/): kind + Online Boutique + Chaos Mesh, with per-role RBAC under the hooks.

## Development

```
bats tests/          # scripts, hooks and docs
claude plugin validate .
claude --plugin-dir .   # load the plugin from this checkout
```

The design and specs live in [openspec/](openspec/).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and the [code of conduct](CODE_OF_CONDUCT.md). Changes are listed in [CHANGELOG.md](CHANGELOG.md).

A way around a guardrail is a security problem: report it privately, as [SECURITY.md](SECURITY.md) describes.

## License

[MIT](LICENSE)
