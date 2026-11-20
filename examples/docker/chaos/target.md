---
kind: sandbox
name: chaos-example containers (api + store)
may_affect: the chaos-example-api and chaos-example-store containers and their network, all labelled chaos.sandbox=chaos-example
must_not_affect: any other container, network or image, and anything on the host outside docker
fidelity:
---

# Target

Two containers built from `app/`: an `api` on 127.0.0.1:18080 that proxies `GET /items` to a `store`.
The api runs with `--restart on-failure`.

## Steady state

- `GET /health` answers 200.
- `GET /items` answers within 2s: 200 with the items, or 503 if the store is unavailable.

## Identity

`up` stamps both containers and the network with `chaos.sandbox=chaos-example` and a random
`chaos.instance` id, and writes the id to `chaos/.sandbox-instance`. `guard` passes only if both
containers carry that exact pair, so a same-named container from somewhere else is refused.

## Evidence

Timestamped `docker logs` for both containers since the fault, and each container's status,
pause state and restart count.
