#!/bin/bash
# NetworkPolicy all-deny in lockdown: selects every Pod, restricts Ingress and Egress, allows nothing

J=$(kubectl get networkpolicy all-deny -n lockdown -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ NetworkPolicy 'all-deny' not found in namespace 'lockdown'"; exit 1; }

echo "$J" | jq -e '((.spec.podSelector.matchLabels // {}) | length == 0) and ((.spec.podSelector.matchExpressions // []) | length == 0)' >/dev/null \
  || { echo "❌ The policy does not select every Pod of the namespace (podSelector must be empty)"; exit 1; }
echo "$J" | jq -e '((.spec.policyTypes // []) | index("Ingress") != null) and ((.spec.policyTypes // []) | index("Egress") != null)' >/dev/null \
  || { echo "❌ policyTypes must contain both Ingress and Egress"; exit 1; }
echo "$J" | jq -e '((.spec.ingress // []) | length == 0) and ((.spec.egress // []) | length == 0)' >/dev/null \
  || { echo "❌ The policy has ingress or egress rules: a deny-all policy allows nothing"; exit 1; }

echo "✅ all-deny selects every Pod and denies all ingress and egress"
exit 0
