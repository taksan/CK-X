#!/bin/bash
# Validate NetworkPolicy restricted-policy exists in dev-team and selects products-service

NS="dev-team"

JSON=$(kubectl get networkpolicy restricted-policy -n "$NS" -o json 2>/dev/null)
if [ -z "$JSON" ]; then
  echo "❌ NetworkPolicy 'restricted-policy' not found in namespace '$NS'"
  exit 1
fi

if ! echo "$JSON" | jq -e '(.spec.policyTypes // []) | index("Ingress") != null' >/dev/null; then
  echo "❌ The policy does not restrict Ingress"
  exit 1
fi

# it must apply to products-service: either every pod or a selector that matches its labels
LABELS=$(kubectl get pod products-service -n "$NS" -o json 2>/dev/null | jq -c '.metadata.labels')
if [ -z "$LABELS" ] || ! echo "$JSON" | jq -e --argjson l "$LABELS" '
    ((.spec.podSelector.matchLabels // {}) | to_entries | all(. as $e | $l[$e.key] == $e.value))
    and ((.spec.podSelector.matchExpressions // []) | length == 0)' >/dev/null; then
  echo "❌ The policy does not select the Pod products-service"
  exit 1
fi

echo "✅ NetworkPolicy 'restricted-policy' exists, restricts ingress and selects products-service"
exit 0
