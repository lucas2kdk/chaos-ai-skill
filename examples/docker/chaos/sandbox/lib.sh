# Shared by chaos/sandbox/* and the hypotheses. Source it; do not execute it.
CHAOS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$CHAOS/../app"
DOCKER="${DOCKER:-docker}"
PROJECT=chaos-example
NET="$PROJECT-net"
API="$PROJECT-api"
STORE="$PROJECT-store"
IMAGE="$PROJECT:local"
API_URL="http://127.0.0.1:18080"
# Written by `up`, read by `guard`: a random id stamped on everything this sandbox owns.
INSTANCE_FILE="$CHAOS/.sandbox-instance"

instance() { cat "$INSTANCE_FILE" 2>/dev/null; }

# get <path> <max-seconds>: prints "<http-code> <seconds>"; code 000 means no answer in time.
get() {
  curl -s -o /dev/null --max-time "$2" -w '%{http_code} %{time_total}' "$API_URL$1" || true
}
