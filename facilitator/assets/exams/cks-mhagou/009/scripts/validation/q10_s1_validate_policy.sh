#!/bin/bash
# Item: NetworkPolicy deny-all in testing selects every Pod, isolates ingress and egress and allows nothing

NS="testing"
P=$(kubectl get networkpolicy deny-all -n "$NS" -o json 2>/dev/null)
[ -n "$P" ] || { echo "❌ NetworkPolicy deny-all not found in namespace $NS"; exit 1; }

echo "$P" | jq -e '((.spec.podSelector.matchLabels // {}) | length == 0) and ((.spec.podSelector.matchExpressions // []) | length == 0)' >/dev/null \
  || { echo "❌ deny-all does not select all Pods of the namespace (podSelector must be empty)"; exit 1; }
for t in Ingress Egress; do
  echo "$P" | jq -e --arg t "$t" '(.spec.policyTypes // []) | index($t) != null' >/dev/null || { echo "❌ deny-all does not isolate $t (policyTypes: $(echo "$P" | jq -c '.spec.policyTypes // []'))"; exit 1; }
done
echo "$P" | jq -e '((.spec.ingress // []) | length == 0) and ((.spec.egress // []) | length == 0)' >/dev/null \
  || { echo "❌ deny-all must not allow any traffic (ingress and egress rules must be empty)"; exit 1; }

OTHER=$(kubectl get networkpolicy -n "$NS" -o json | jq -r '[.items[] | select(.metadata.name != "deny-all" and (((.spec.ingress // []) | length > 0) or ((.spec.egress // []) | length > 0)))] | map(.metadata.name) | join(",")')
[ -z "$OTHER" ] || { echo "❌ Another NetworkPolicy of the namespace allows traffic: $OTHER"; exit 1; }

echo "✅ deny-all selects all Pods, isolates ingress and egress and allows nothing"
exit 0
