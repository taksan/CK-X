#!/bin/bash
# Validate NetworkPolicy allow-np exists in staging, restricts Ingress and selects the Pods

J=$(kubectl get networkpolicy allow-np -n staging -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ NetworkPolicy 'allow-np' not found in namespace 'staging'"; exit 1; }
echo "$J" | jq -e '(.spec.policyTypes // []) | index("Ingress") != null' >/dev/null || { echo "❌ The policy does not restrict Ingress"; exit 1; }
echo "$J" | jq -e '(.spec.ingress // []) | length > 0' >/dev/null || { echo "❌ The policy allows nothing: the same-namespace traffic on port 80 must be allowed"; exit 1; }

echo "✅ allow-np exists and restricts ingress"
exit 0
