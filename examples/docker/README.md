# Example: Docker

The smallest complete binding: two containers built from `app/`, an `api` that proxies `GET /items` to a `store`. Needs Docker and curl.

The api has one seeded resilience bug: it calls the store with no timeout and no fallback.

| Hypothesis | Fault | Expected result |
|---|---|---|
| `api-crash` | kill the api process (one-off) | **held**: the restart policy brings it back within 15s |
| `store-freeze` | `docker pause` the store for up to 60s | **violated**: `/items` hangs instead of answering 503 within 2s |

## Try it

With the plugin installed, from this directory:

```
/chaos:run store-freeze
```

The binding and both hypotheses are already reviewed: their stamps are in `chaos/.review`. Change anything in `chaos/target.md`, `chaos/sandbox/` or a hypothesis, and runs refuse to start until you review it and run `validate --stamp binding` or `validate --stamp hypothesis <id>` again.

Without Claude, the same run by hand (the plugin's `scripts/` on `PATH`):

```
phase start store-freeze
phase up
phase guard
phase baseline         # the api is healthy before any fault
phase to inject
phase fault apply      # prints "fault active (confirmed)"
phase to observe
phase check            # waits 5s, then exits 1: the hypothesis is violated
phase evidence
phase fault revert
phase recover          # "recovered after 0s": unpausing the store heals it at once
phase to cleanup
phase end not-reproducible
```

## Fix the bug

In `app/api.py`, give `urlopen` a timeout and return a 503 when the store does not answer. Then `/chaos:verify` on the finding reports it fixed.
