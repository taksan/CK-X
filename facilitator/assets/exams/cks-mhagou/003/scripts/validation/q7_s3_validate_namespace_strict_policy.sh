#!/bin/bash
# Validate a namespace-wide PeerAuthentication in restricted-zone: no selector, mode STRICT and no
# port-level exception

J=$(kubectl get peerauthentication -n restricted-zone -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Unable to read the PeerAuthentication policies of restricted-zone"; exit 1; }

N=$(echo "$J" | jq '.items | length')
[ "$N" != "0" ] || { echo "❌ No PeerAuthentication in namespace restricted-zone"; exit 1; }

echo "$J" | jq -e '[.items[] | select(((.spec.selector.matchLabels // {}) | length) == 0) | select(.spec.mtls.mode == "STRICT")] | length > 0' >/dev/null \
  || { echo "❌ No PeerAuthentication of restricted-zone without a selector requires mtls mode STRICT"; exit 1; }

echo "$J" | jq -e '[.items[] | select((.spec.portLevelMtls // {}) | length > 0) | select([.spec.portLevelMtls[]?.mode] | any(. != "STRICT"))] | length == 0' >/dev/null \
  || { echo "❌ A port-level exception weakens the STRICT mode (portLevelMtls)"; exit 1; }
echo "$J" | jq -e '[.items[] | select(((.spec.selector.matchLabels // {}) | length) > 0) | select(.spec.mtls.mode != "STRICT")] | length == 0' >/dev/null \
  || { echo "❌ A workload-level PeerAuthentication weakens the STRICT mode"; exit 1; }

echo "✅ The namespace restricted-zone has a STRICT PeerAuthentication without exceptions"
exit 0
