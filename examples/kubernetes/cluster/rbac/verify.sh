#!/usr/bin/env bash
# Negative and positive RBAC checks. Exits non-zero if any role can do more or less than intended.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/../lib.sh"
"$here/../guard.sh" "$KUBE_CONTEXT"
kc="$here/../kubeconfigs"
fail=0

# expect <yes|no> <role> <args to kubectl auth can-i>
expect() {
  local want=$1 role=$2; shift 2
  local got
  got=$(kubectl --kubeconfig "$kc/$role.kubeconfig" auth can-i "$@" 2>/dev/null)
  if [[ "$got" == "$want" ]]; then
    echo "ok   $role can-i $* -> $got"
  else
    echo "FAIL $role can-i $* -> $got (want $want)"; fail=1
  fi
}

expect yes injector create podchaos.chaos-mesh.org -n boutique
expect yes injector delete networkchaos.chaos-mesh.org -n boutique
expect no  injector create podchaos.chaos-mesh.org -n default
expect no  injector create podchaos.chaos-mesh.org -n kube-system
expect no  injector create iochaos.chaos-mesh.org -n boutique
expect no  injector delete pods -n boutique
expect no  injector create deployments.apps -n boutique

for role in observer triager; do
  expect yes $role get pods/log -n boutique
  expect yes $role list podchaos.chaos-mesh.org -n boutique
  expect yes $role get services/prometheus-server:80 -n monitoring --subresource=proxy
  expect no  $role create podchaos.chaos-mesh.org -n boutique
  expect no  $role delete pods -n boutique
  expect no  $role create networkchaos.chaos-mesh.org -n boutique
  expect no  $role get secrets -n boutique
  expect no  $role create podchaos.chaos-mesh.org -n default
done

# Reporter has no kubeconfig at all.
if [[ -e "$kc/reporter.kubeconfig" ]]; then echo "FAIL reporter kubeconfig exists"; fail=1; else echo "ok   reporter has no kubeconfig"; fi
exit $fail
