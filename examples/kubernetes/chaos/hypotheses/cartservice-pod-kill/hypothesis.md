---
id: cartservice-pod-kill
steady_state: GET /cart on the frontend returns 200 within 2s while a cartservice pod is killed
fault: PodChaos pod-kill on one cartservice pod
duration: 120s
wait: 5s
check_timeout: 45s
recovers_within: 60s
---
**Steady state:** `GET /cart` on the frontend keeps returning 200 within 2s while a cartservice pod is killed.
