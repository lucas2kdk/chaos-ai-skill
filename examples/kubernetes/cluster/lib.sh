# Shared by every script in cluster/. Source it; do not execute it.
# All kubectl calls go through `k` so they can never hit the wrong cluster.
CLUSTER_NAME=chaos-ai
KUBE_CONTEXT="kind-${CLUSTER_NAME}"
TARGET_NS=boutique
CHAOS_NS=chaos-mesh

k() { kubectl --context "$KUBE_CONTEXT" "$@"; }
