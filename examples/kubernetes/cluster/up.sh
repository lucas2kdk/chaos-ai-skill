#!/usr/bin/env bash
# Create the throwaway cluster and install Online Boutique, Chaos Mesh, Prometheus.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/lib.sh"

BOUTIQUE_VERSION=v0.10.2
CHAOS_MESH_VERSION=2.7.2
PROM_CHART_VERSION=27.5.1

kind get clusters | grep -qx "$CLUSTER_NAME" || kind create cluster --config "$here/kind-config.yaml"
"$here/guard.sh" "$KUBE_CONTEXT"

k create namespace "$TARGET_NS" --dry-run=client -o yaml | k apply -f -
k apply -n "$TARGET_NS" -f \
  "https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/${BOUTIQUE_VERSION}/release/kubernetes-manifests.yaml"

helm repo add chaos-mesh https://charts.chaos-mesh.org >/dev/null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update >/dev/null

# kind nodes run containerd
helm --kube-context "$KUBE_CONTEXT" upgrade --install chaos-mesh chaos-mesh/chaos-mesh \
  --namespace "$CHAOS_NS" --create-namespace --version "$CHAOS_MESH_VERSION" \
  --set chaosDaemon.runtime=containerd \
  --set chaosDaemon.socketPath=/run/containerd/containerd.sock \
  --set dashboard.create=false

helm --kube-context "$KUBE_CONTEXT" upgrade --install prometheus prometheus-community/prometheus \
  --namespace monitoring --create-namespace --version "$PROM_CHART_VERSION" \
  --set alertmanager.enabled=false --set prometheus-pushgateway.enabled=false

"$here/wait-ready.sh"
