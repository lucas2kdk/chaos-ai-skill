#!/usr/bin/env bash
# Abort unless the cluster being targeted is the dedicated test cluster.
# Checks the ACTIVE kube context by default, or the one given as $1.
# Pipeline entry points must run this before creating anything.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/lib.sh"

ctx="${1:-$(kubectl config current-context)}"
if [[ "$ctx" != "$KUBE_CONTEXT" ]]; then
  echo "guard: refusing to run against context '$ctx' (expected '$KUBE_CONTEXT')" >&2
  exit 1
fi
