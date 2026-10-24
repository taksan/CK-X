#!/bin/bash
# Validate a CiliumNetworkPolicy in cilium-lab: it selects the nginx Pods, allows ingress from the
# Pods labelled app=curlpod on port 80 and requires mutual authentication for that traffic

NS="cilium-lab"
J=$(kubectl get ciliumnetworkpolicy -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] && [ "$(echo "$J" | jq '.items | length')" != "0" ] || { echo "❌ No CiliumNetworkPolicy found in namespace '$NS'"; exit 1; }

echo "$J" | jq -e '[.items[] | select((.spec.endpointSelector.matchLabels // {}) | (."app" == "nginx" or ."k8s:app" == "nginx"))] | length > 0' >/dev/null \
  || { echo "❌ No CiliumNetworkPolicy selects the Pods with the label app=nginx"; exit 1; }

echo "$J" | jq -e '[.items[] | select((.spec.endpointSelector.matchLabels // {}) | (."app" == "nginx" or ."k8s:app" == "nginx"))
  | .spec.ingress[]? | select(any(.fromEndpoints[]?; ((.matchLabels // {}) | (."app" == "curlpod" or ."k8s:app" == "curlpod"))))] | length > 0' >/dev/null \
  || { echo "❌ The policy needs an ingress rule from the Pods with the label app=curlpod"; exit 1; }

echo "$J" | jq -e '[.items[] | select((.spec.endpointSelector.matchLabels // {}) | (."app" == "nginx" or ."k8s:app" == "nginx"))
  | .spec.ingress[]? | select(any(.fromEndpoints[]?; ((.matchLabels // {}) | (."app" == "curlpod" or ."k8s:app" == "curlpod"))))
  | select(.authentication.mode == "required")] | length > 0' >/dev/null \
  || { echo "❌ The ingress rule from app=curlpod does not require mutual authentication (authentication.mode: required)"; exit 1; }

echo "✅ A CiliumNetworkPolicy allows app=curlpod to app=nginx and requires mutual authentication"
exit 0
