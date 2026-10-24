#!/bin/bash
# Item: DNS (UDP/53 and TCP/53) is allowed to any destination, even inside the malicious ranges

NS="threat-prevention"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
kubectl get networkpolicy block-malicious-egress -n "$NS" -o json > "$TMP" 2>/dev/null || { echo "❌ NetworkPolicy 'block-malicious-egress' not found in namespace '$NS'"; exit 1; }

R=$(python3 "$(dirname "$0")/../lib/netpol_q3.py" "$TMP" dns) || { echo "❌ $R"; exit 1; }

echo "✅ DNS over UDP/53 and TCP/53 is allowed to any destination"
exit 0
