#!/bin/bash
# Item: CiliumNetworkPolicy p1 exists in team-azure and selects the Pods with role=messenger

J=$(kubectl get ciliumnetworkpolicy p1 -n team-azure -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ CiliumNetworkPolicy 'p1' not found in namespace 'team-azure'"; exit 1; }

if ! echo "$J" | jq -e '[.spec.endpointSelector.matchLabels["role"], .spec.endpointSelector.matchLabels["k8s:role"]] | any(. == "messenger")' >/dev/null 2>&1 \
   && ! echo "$J" | jq -e 'any(.spec.endpointSelector.matchExpressions[]?; (.key == "role" or .key == "k8s:role") and .operator == "In" and (.values | index("messenger") != null))' >/dev/null 2>&1; then
  echo "❌ The policy p1 must select the Pods with the label role=messenger (endpointSelector)"
  exit 1
fi

echo "✅ p1 exists and selects the role=messenger Pods"
exit 0
