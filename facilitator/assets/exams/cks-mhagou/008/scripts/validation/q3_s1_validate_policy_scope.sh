#!/bin/bash
# Item: NetworkPolicy block-malicious-egress exists in threat-prevention, selects every Pod and
# restricts egress only (not ingress)

NS="threat-prevention"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
kubectl get networkpolicy block-malicious-egress -n "$NS" -o json > "$TMP" 2>/dev/null || { echo "❌ NetworkPolicy 'block-malicious-egress' not found in namespace '$NS'"; exit 1; }

R=$(python3 "$(dirname "$0")/../lib/netpol_q3.py" "$TMP" select) || { echo "❌ $R"; exit 1; }

echo "✅ block-malicious-egress selects all Pods and restricts egress only"
exit 0
