#!/bin/bash
# Validate that NetworkPolicy deny-all selects every pod and allows no ingress or egress

POLICY_NAME="deny-all"
NAMESPACE="testing"

JSON=$(kubectl get networkpolicy "$POLICY_NAME" -n "$NAMESPACE" -o json 2>/dev/null)
if [ -z "$JSON" ]; then
  echo "❌ NetworkPolicy '$POLICY_NAME' not found in namespace '$NAMESPACE'"
  exit 1
fi

# The API server drops empty lists, so "no rules" means the field is absent or empty.
if ! echo "$JSON" | jq -e '(.spec.policyTypes // []) | (index("Ingress") != null and index("Egress") != null)' >/dev/null; then
  echo "❌ NetworkPolicy does not include both Ingress and Egress in policyTypes"
  exit 1
fi

if ! echo "$JSON" | jq -e '(.spec.podSelector // {}) == {}' >/dev/null; then
  echo "❌ NetworkPolicy does not select all pods in the namespace (podSelector must be empty)"
  exit 1
fi

if ! echo "$JSON" | jq -e '((.spec.ingress // []) | length) == 0' >/dev/null; then
  echo "❌ NetworkPolicy allows some ingress traffic (it must have no ingress rules)"
  exit 1
fi

if ! echo "$JSON" | jq -e '((.spec.egress // []) | length) == 0' >/dev/null; then
  echo "❌ NetworkPolicy allows some egress traffic (it must have no egress rules)"
  exit 1
fi

echo "✅ NetworkPolicy denies all ingress and egress for all pods in the namespace"
exit 0
