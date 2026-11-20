# Shared by chaos/sandbox/* and the hypothesis faults. Source it; do not execute it.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/cluster/lib.sh"   # CLUSTER_NAME, KUBE_CONTEXT, TARGET_NS
INJ="$ROOT/cluster/kubeconfigs/injector.kubeconfig"
OBS="$ROOT/cluster/kubeconfigs/observer.kubeconfig"

# chaos_fault <manifest> <deployment> <apply|revert|status>
# Applies and deletes the Chaos Mesh manifest with the injector's scoped credentials. Revert also waits
# (read-only) for the deployment to be available again, so a repeat fault starts from a healthy target.
chaos_fault() {
  local manifest=$1 deploy=$2
  case "${3:-}" in
    apply) kubectl --kubeconfig "$INJ" create -f "$manifest" ;;   # create, not apply: fails if one is left over
    revert)
      kubectl --kubeconfig "$INJ" delete -f "$manifest" --ignore-not-found >/dev/null &&
        kubectl --kubeconfig "$OBS" -n "$TARGET_NS" rollout status "deploy/$deploy" --timeout=180s >/dev/null
      ;;
    status)
      if [[ -n "$(kubectl --kubeconfig "$INJ" get -f "$manifest" -o name --ignore-not-found 2>/dev/null)" ]]; then
        echo active
      else
        echo inactive
      fi
      ;;
    *) echo "usage: fault apply|revert|status" >&2; return 2 ;;
  esac
}
