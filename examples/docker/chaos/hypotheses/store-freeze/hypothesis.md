---
id: store-freeze
steady_state: GET /items answers within 2s, with 200 or a 503 fallback, while the store is frozen
fault: docker pause on the store container for up to 60s
duration: 60s
wait: 5s
check_timeout: 30s
recovers_within: 20s
abort_interval: 5s
---
**Steady state:** `GET /items` on the api answers within 2s, with the items (200) or a fast failure (503), while the store container is frozen.

A frozen dependency is worse than a dead one: connections open but nothing comes back. Without a timeout, every request to the api waits on it.
