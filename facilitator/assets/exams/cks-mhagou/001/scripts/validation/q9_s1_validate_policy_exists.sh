#!/bin/bash
# Item: NetworkPolicy allow-redis-access exists in prod-x12cs, selects redis-backend and restricts ingress

J=$(kubectl get networkpolicy allow-redis-access -n prod-x12cs -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ NetworkPolicy 'allow-redis-access' not found in namespace 'prod-x12cs'"; exit 1; }

echo "$J" | jq -e '(.spec.policyTypes // []) | index("Ingress") != null' >/dev/null || { echo "❌ The policy does not restrict Ingress (policyTypes)"; exit 1; }

SEL=$(echo "$J" | jq -c '.spec.podSelector')
POD_LABELS=$(kubectl get pod redis-backend -n prod-x12cs -o json 2>/dev/null | jq -c '.metadata.labels')
if ! echo "$SEL" | jq -e --argjson l "${POD_LABELS:-null}" '((.matchLabels // {}) | length > 0) and ((.matchLabels // {}) | to_entries | all(. as $e | $l[$e.key] == $e.value))' >/dev/null 2>&1; then
  echo "❌ The policy does not select the Pod redis-backend through its existing labels (podSelector: $SEL)"
  exit 1
fi

echo "✅ allow-redis-access selects redis-backend and restricts ingress"
exit 0
