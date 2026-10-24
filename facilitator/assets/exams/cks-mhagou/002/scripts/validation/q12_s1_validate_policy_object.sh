#!/bin/bash
# NetworkPolicy np-restriction in moon: selects nginx-pod and restricts Ingress

J=$(kubectl get networkpolicy np-restriction -n moon -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ NetworkPolicy 'np-restriction' not found in namespace 'moon'"; exit 1; }
echo "$J" | jq -e '(.spec.policyTypes // []) | index("Ingress") != null' >/dev/null || { echo "❌ The policy does not restrict Ingress"; exit 1; }

# it must select nginx-pod (by its label or by an empty selector) and not leave it out
SEL=$(echo "$J" | jq -c '.spec.podSelector')
if ! kubectl get pods -n moon -l "$(echo "$SEL" | jq -r '(.matchLabels // {}) | to_entries | map("\(.key)=\(.value)") | join(",")')" -o name 2>/dev/null | grep -q 'pod/nginx-pod'; then
  echo "❌ The policy does not select the Pod nginx-pod (podSelector: $SEL)"
  exit 1
fi

echo "✅ np-restriction exists and restricts the ingress of nginx-pod"
exit 0
