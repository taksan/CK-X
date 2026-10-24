#!/bin/bash
# Item: egress to 192.168.100.0/24 and 10.0.99.0/24 is denied (except DNS) and every other
# destination stays reachable on every port (the rules are evaluated for sample addresses)

NS="threat-prevention"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
kubectl get networkpolicy block-malicious-egress -n "$NS" -o json > "$TMP" 2>/dev/null || { echo "❌ NetworkPolicy 'block-malicious-egress' not found in namespace '$NS'"; exit 1; }

R=$(python3 "$(dirname "$0")/../lib/netpol_q3.py" "$TMP" cidrs) || { echo "❌ $R"; exit 1; }

echo "✅ The two malicious /24 ranges are blocked, all other egress is allowed"
exit 0
