---
id: api-crash
steady_state: GET /health answers 200 again within 15s after the api process crashes
fault: kill the api process inside its container (a one-off event)
duration: 30s
wait: 0s
check_timeout: 20s
recovers_within: 20s
one_off: true
---
**Steady state:** after the api process is killed, `GET /health` answers 200 again within 15s.

The api container runs with `--restart on-failure`, so a crash should be absorbed by a restart. This checks that it is.
The fault is a one-off event (`one_off: true`): once the process is killed there is nothing to revert, so `status` always reports inactive. `wait: 0s` makes the check start right after the kill, so it measures how quickly the api comes back.
