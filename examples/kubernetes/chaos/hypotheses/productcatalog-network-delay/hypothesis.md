---
id: productcatalog-network-delay
steady_state: GET / on the frontend returns 200 within 1.5s while productcatalogservice has 2s of network delay
fault: NetworkChaos 2s delay on productcatalogservice
duration: 120s
wait: 5s
check_timeout: 45s
recovers_within: 60s
---
**Steady state:** `GET /` on the frontend returns 200 within 1.5s while productcatalogservice has a 2s network delay.

Every storefront page calls productcatalogservice, so a missing timeout or fallback shows up as slow pages.
