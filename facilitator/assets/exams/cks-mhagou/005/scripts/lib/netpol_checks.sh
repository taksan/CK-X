#!/bin/bash
# Helpers on top of netpol_eval.py (source with: source "$(dirname "$0")/../lib/netpol_checks.sh")
#   load_netpol NS POD             reads the NetworkPolicies of NS and the Pod (returns 1 with a message when the Pod is missing)
#   egress_allowed IP PORT PROTO   0 when the egress of the Pod to that external address is allowed (reason in EGRESS_REASON)

NETPOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETPOL_WORK=""

load_netpol() {
  NETPOL_WORK=$(mktemp -d)
  trap 'rm -rf "$NETPOL_WORK"' EXIT
  if ! kubectl get pod "$2" -n "$1" -o json > "$NETPOL_WORK/pod.json" 2>/dev/null; then
    echo "❌ The Pod $2 of the namespace $1 was deleted"
    return 1
  fi
  kubectl get networkpolicy -n "$1" -o json > "$NETPOL_WORK/policies.json" 2>/dev/null || echo '{"items":[]}' > "$NETPOL_WORK/policies.json"
}

egress_allowed() {
  EGRESS_REASON=$(python3 "$NETPOL_DIR/netpol_eval.py" "$NETPOL_WORK/policies.json" "$NETPOL_WORK/pod.json" "$1" "$2" "$3" 2>&1)
}
