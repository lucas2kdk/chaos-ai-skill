# Contributing

Issues and pull requests are welcome. For anything larger than a fix, open an issue first so we can agree on the shape before you write it.

Security problems, including ways around the guardrails, go through [SECURITY.md](SECURITY.md), not a public issue.

## Setup

You need `bash`, `jq`, [`bats`](https://github.com/bats-core/bats-core) and [`shellcheck`](https://www.shellcheck.net/). The examples also need Docker, and the Kubernetes one needs kind, kubectl and helm.

```
bats tests/               # scripts, hooks and docs
claude plugin validate .
claude --plugin-dir .     # load the plugin from this checkout
```

CI runs `bats tests/` and `shellcheck` on every pull request.

On Windows, work in WSL. The scripts are bash and depend on the executable bit.

## What a change needs

- **Tests.** Scripts and hooks are covered by `tests/*.bats`. A change in behaviour comes with a test that fails without it.
- **Docs.** `tests/docs.bats` fails when the docs fall behind the code:
  - a new script in `scripts/` needs a row in [docs/contracts.md](docs/contracts.md);
  - a command the guardrail hook distinguishes needs a row in [docs/guardrails.md](docs/guardrails.md);
  - a finding frontmatter field needs a row in [docs/finding-format.md](docs/finding-format.md).
- **Executable bit.** New scripts, and the `fault`, `check`, `abort` and `sandbox/*` files, must be committed executable: `git add --chmod=+x <file>`.
- **Review stamps.** If you edit an example's binding or a hypothesis, its stamp in `chaos/.review` no longer matches. Read the change again, then run `scripts/validate --stamp binding` or `scripts/validate --stamp hypothesis <id>` from the example directory.

A guardrail that gets weaker needs a reason in the pull request, and usually a new entry under "Known gaps" in `docs/guardrails.md`.

## Larger changes

The design and specs live in [openspec/](openspec/). A change that adds or alters behaviour starts as an [OpenSpec](https://github.com/Fission-AI/OpenSpec) change under `openspec/changes/`, with a proposal, the spec deltas and tasks. The generated agent skills (`.claude/`, `.agents/`) are not committed; run `openspec init` to create them.

## Commits

Start the subject with a [gitmoji](https://gitmoji.dev/) as the Unicode character, then a space: `🐛 Fix watchdog revert on expiry`.
