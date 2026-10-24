#!/bin/bash
# Validate a namespace-wide PeerAuthentication in STRICT mode (no workload selector)

NAMESPACE="${Q6_NAMESPACE:-payments}"

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "❌ Namespace '$NAMESPACE' not found"
  exit 1
fi

JSON=$(kubectl get peerauthentication -n "$NAMESPACE" -o json 2>/dev/null)
if [ "$(echo "$JSON" | jq '.items | length' 2>/dev/null)" = "0" ] || [ -z "$JSON" ]; then
  echo "❌ No PeerAuthentication found in namespace '$NAMESPACE'"
  exit 1
fi

# applies to every workload (no selector, or an empty one); STRICT mode
if ! echo "$JSON" | jq -e '[.items[] | select(((.spec.selector.matchLabels // {}) | length) == 0 and .spec.mtls.mode == "STRICT")] | length > 0' >/dev/null; then
  echo "❌ No namespace-wide PeerAuthentication (without a workload selector) with mtls.mode=STRICT in '$NAMESPACE'"
  exit 1
fi

echo "✅ A PeerAuthentication enforces mTLS STRICT for all workloads in '$NAMESPACE'"
exit 0
