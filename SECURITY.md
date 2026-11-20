# Security

This plugin gives an agent a shell and permission to break things. Its guardrails are the security boundary, so a way around one is a vulnerability.

## Reporting

Report privately through [GitHub security advisories](https://github.com/lucas2kdk/chaos-ai-skill/security/advisories/new). Please don't open a public issue.

Include what you ran, what happened, and what you expected the guardrail to do. A minimal `chaos/` directory that reproduces it helps most.

This is a personal project maintained in spare time, so an answer can take a few days.

## In scope

- Running a command the current phase should not allow (`hooks/guardrail`).
- Moving a run backwards, or injecting after observe beyond the single triage repeat.
- Injecting a fault when `guard` fails, or without the confirmation an existing target requires.
- A fault that outlives its time box: the watchdog or the stop hook not reverting it.
- Running against a binding or hypothesis that changed after it was reviewed.
- A credential that passes `sanitize --detect` and reaches a sink, where the pattern is one `sanitize` claims to catch.

## Known gaps

[docs/guardrails.md](docs/guardrails.md) lists what the guardrails do not cover, for example that a reviewed fault script has the access of the user who runs it. Those are documented limits, not vulnerabilities. Improvements are welcome as normal issues and pull requests.

## Supported versions

Only the latest release gets fixes.
