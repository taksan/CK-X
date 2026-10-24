#!/bin/bash
# Validate NetworkPolicy default-deny in egress-lab: restricts Egress for every Pod

NS="egress-lab"

JSON=$(kubectl get networkpolicy default-deny -n "$NS" -o json 2>/dev/null)
[ -n "$JSON" ] || { echo "❌ NetworkPolicy 'default-deny' not found in namespace '$NS'"; exit 1; }

echo "$JSON" | jq -e '(.spec.policyTypes // []) | index("Egress") != null' >/dev/null || { echo "❌ The policy does not restrict Egress"; exit 1; }
echo "$JSON" | jq -e '((.spec.podSelector.matchLabels // {}) | length == 0) and ((.spec.podSelector.matchExpressions // []) | length == 0)' >/dev/null || { echo "❌ The policy does not select all Pods of the namespace"; exit 1; }

echo "✅ NetworkPolicy 'default-deny' restricts the egress of all Pods in '$NS'"
exit 0
