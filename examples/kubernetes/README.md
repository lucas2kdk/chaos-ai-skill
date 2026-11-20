# Example: Kubernetes

A local kind cluster running [Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo) with Chaos Mesh and Prometheus. Needs Docker, kind, kubectl and helm.

This binding shows Kubernetes credentials stacked under the plugin's hooks. `chaos/sandbox/up` issues one ServiceAccount and kubeconfig per role:

| Credential | Can | Used by |
|---|---|---|
| `injector.kubeconfig` | create/delete PodChaos, NetworkChaos, StressChaos in `boutique` only | the hypotheses' `fault` |
| `observer.kubeconfig` | read pods, logs, events, chaos objects; GET the frontend and Prometheus through the API proxy | `check`, `evidence`, `guard` |
| `triager.kubeconfig` | the same read-only access as the observer | nothing in this binding; there for reading the cluster by hand while triaging |

`cluster/rbac/verify.sh` proves what each can and cannot do. Your current kube context is never used.

| Hypothesis | Fault |
|---|---|
| `cartservice-pod-kill` | kill the single cartservice pod |
| `productcatalog-network-delay` | 2s network delay on productcatalogservice |
| `redis-cart-loss` | redis-cart unavailable for 120s |

## Try it

```
chaos/sandbox/up            # first time: creates the cluster (several minutes)
cluster/rbac/verify.sh
/chaos:run cartservice-pod-kill
```

`keep_sandbox: true` in `chaos/config.yaml` keeps the cluster between runs. `chaos/sandbox/down` deletes it.

Each fault uses `kubectl create`, not `apply`, so a chaos object left over from an earlier run makes the fault fail loudly instead of silently doing nothing.
