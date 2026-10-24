#!/bin/bash
# Validate an Istio AuthorizationPolicy in mesh-lab selects the orders workload with an ALLOW rule

NS="mesh-lab"
J=$(kubectl get authorizationpolicy -n "$NS" -o json 2>/dev/null)
echo "$J" | jq -e '[.items[] | select((.spec.selector.matchLabels.app // "") == "orders" and ((.spec.action // "ALLOW") == "ALLOW") and ((.spec.rules // []) | length > 0))] | length > 0' >/dev/null \
  || { echo "❌ No AuthorizationPolicy in '$NS' selects app=orders with an ALLOW rule"; exit 1; }

echo "✅ An ALLOW AuthorizationPolicy for orders exists"
exit 0
