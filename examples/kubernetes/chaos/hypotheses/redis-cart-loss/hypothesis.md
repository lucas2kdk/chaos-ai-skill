---
id: redis-cart-loss
steady_state: GET /cart on the frontend returns 200 within 2s while redis-cart is unavailable
fault: PodChaos pod-failure on redis-cart for 120s
duration: 120s
wait: 5s
check_timeout: 45s
recovers_within: 60s
---
**Steady state:** `GET /cart` on the frontend keeps returning 200 within 2s while redis-cart is unavailable for 120s.

Cart data lives only in redis-cart, so this checks whether the cart degrades gracefully without it.
