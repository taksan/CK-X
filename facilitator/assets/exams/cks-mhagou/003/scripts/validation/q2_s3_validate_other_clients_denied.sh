#!/bin/bash
# Validate by behaviour: only curlpod may reach nginx; the Pod other is denied
# (credited only with a policy that selects nginx: without any policy everything is allowed)

NS="cilium-lab"

kubectl get ciliumnetworkpolicy -n "$NS" -o json 2>/dev/null \
  | jq -e '[.items[] | select((.spec.endpointSelector.matchLabels // {}) | (."app" == "nginx" or ."k8s:app" == "nginx"))] | length > 0' >/dev/null \
  || { echo "❌ No CiliumNetworkPolicy selects the nginx Pods yet"; exit 1; }

IP=$(kubectl get pod -n "$NS" -l app=nginx -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)
[ -n "$IP" ] || { echo "❌ nginx has no Pod IP"; exit 1; }

# the policy takes a few seconds to be enforced
for i in $(seq 1 10); do
  kubectl exec -n "$NS" other -- wget -q -T 3 -O /dev/null "http://$IP" >/dev/null 2>&1 || break
  sleep 3
done

if kubectl exec -n "$NS" other -- wget -q -T 3 -O /dev/null "http://$IP" >/dev/null 2>&1; then
  echo "❌ The Pod 'other' (label app=other) can still reach nginx: only app=curlpod may"
  exit 1
fi
if ! kubectl exec -n "$NS" curlpod -- wget -q -T 6 -O /dev/null "http://$IP" >/dev/null 2>&1; then
  echo "❌ curlpod can no longer reach nginx: the policy is too strict"
  exit 1
fi

echo "✅ curlpod reaches nginx, the Pod other is denied"
exit 0
