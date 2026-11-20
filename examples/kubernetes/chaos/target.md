---
kind: sandbox
name: kind cluster chaos-ai, namespace boutique (Online Boutique)
may_affect: pods and network of the boutique namespace in the kind cluster chaos-ai, through PodChaos, NetworkChaos and StressChaos only
must_not_affect: any other cluster or kube context, other namespaces, Secrets, and the host outside the kind containers
fidelity:
---

# Target

A local [kind](https://kind.sigs.k8s.io/) cluster named `chaos-ai` running
[Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo) in namespace `boutique`,
plus Chaos Mesh and Prometheus. `up` creates or updates it; `down` deletes it (only if
`keep_sandbox: false`).

Kubernetes credentials stack on top of the plugin's hooks: `up` issues one ServiceAccount and
kubeconfig per role (`cluster/rbac/`). Faults are applied with the injector kubeconfig, which can only
create and delete PodChaos, NetworkChaos and StressChaos in `boutique`. Checks and evidence use the
read-only observer kubeconfig. `cluster/rbac/verify.sh` proves both.

## Steady state

The frontend, reached read-only through the API server service proxy: `GET /` and `GET /cart` return
200 within the latency bound of each hypothesis.

## Identity

`guard` passes only if the kind cluster `chaos-ai` exists and both scoped kubeconfigs name context
`kind-chaos-ai` and point at that cluster's API server, as reported by `kind get kubeconfig`. Your
current kube context is never used.

## Evidence

Timestamped logs of frontend, cartservice, productcatalogservice and redis-cart since the fault,
events, pod status and the chaos objects, all read with the observer kubeconfig.
