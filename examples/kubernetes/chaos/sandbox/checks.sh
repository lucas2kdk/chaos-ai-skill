# Shared by chaos/hypotheses/*/check. Source it; do not execute it.
# Checks run with the read-only observer credentials and GET through the API server proxy.
export LC_ALL=C  # dot decimals for date/printf/bc
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OBSERVER_KUBECONFIG="${OBSERVER_KUBECONFIG:-$ROOT/cluster/kubeconfigs/observer.kubeconfig}"

# frontend_get <path> -> prints "<ok|ERR> <seconds> [error text]"
# ERR covers any non-2xx from the frontend (the API proxy surfaces them as errors) or no response.
frontend_get() {
  local start end out rc
  start=$(date +%s.%N)
  out=$(kubectl --kubeconfig "$OBSERVER_KUBECONFIG" --request-timeout=5s \
      get --raw "/api/v1/namespaces/boutique/services/frontend:80/proxy$1" 2>&1 >/dev/null)
  rc=$?
  end=$(date +%s.%N)
  local secs
  secs=$(echo "scale=3; $end - $start" | bc -l | sed 's/^\./0./')
  if [[ $rc -eq 0 ]]; then printf 'ok %.2f\n' "$secs"; else printf 'ERR %.2f %s\n' "$secs" "$(head -c 120 <<<"$out" | tr '\n' ' ')"; fi
}

# sample_frontend <path> <samples> <max_seconds_per_request>
# Exit 0 only if every sample returns 200 within the latency bound.
sample_frontend() {
  local path=$1 n=$2 max=$3 i bad=0 code secs
  for ((i = 1; i <= n; i++)); do
    read -r code secs detail < <(frontend_get "$path")
    if [[ "$code" != ok ]] || (( $(echo "$secs > $max" | bc -l) )); then
      echo "VIOLATED sample $i/$n: GET $path -> $code in ${secs}s (limit ${max}s) $detail"
      bad=1
    else
      echo "ok sample $i/$n: GET $path in ${secs}s"
    fi
    sleep 1
  done
  return $bad
}
