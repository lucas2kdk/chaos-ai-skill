#!/usr/bin/env bash
# Apply per-role RBAC and write one scoped kubeconfig per cluster-facing role to cluster/kubeconfigs/.
# The Reporter deliberately gets no kubeconfig: it only runs `gh issue create`.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/../lib.sh"
"$here/../guard.sh" "$KUBE_CONTEXT"

out="$here/../kubeconfigs"
mkdir -p "$out"
k apply -f "$here/roles.yaml"

server=$(k config view --minify --raw -o jsonpath='{.clusters[0].cluster.server}')
ca=$(k config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

for role in injector observer triager; do
  token=$(k -n chaos-agents create token "$role" --duration=24h)
  cat > "$out/$role.kubeconfig" <<KC
apiVersion: v1
kind: Config
clusters:
- name: $CLUSTER_NAME
  cluster: {server: $server, certificate-authority-data: $ca}
users:
- name: $role
  user: {token: $token}
contexts:
- name: $KUBE_CONTEXT
  context: {cluster: $CLUSTER_NAME, user: $role}
current-context: $KUBE_CONTEXT
KC
  chmod 600 "$out/$role.kubeconfig"
done
echo "kubeconfigs written to $out"
