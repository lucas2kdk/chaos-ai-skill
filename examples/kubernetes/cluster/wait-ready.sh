#!/usr/bin/env bash
# Block until every workload in the three namespaces is Ready. Exit non-zero on timeout.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/lib.sh"
"$here/guard.sh" "$KUBE_CONTEXT"

for ns in "$TARGET_NS" "$CHAOS_NS" monitoring; do
  k -n "$ns" wait --for=condition=Available deployment --all --timeout=600s
done
k -n "$CHAOS_NS" rollout status daemonset --timeout=300s
k -n monitoring rollout status daemonset --timeout=300s
echo "all workloads ready"
