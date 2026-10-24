#!/bin/bash
# Validate a mesh-wide PeerAuthentication (root namespace istio-system, no selector) in STRICT mode

J=$(kubectl get peerauthentication -n istio-system -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Unable to read the PeerAuthentication policies of istio-system"; exit 1; }

echo "$J" | jq -e '[.items[] | select(((.spec.selector.matchLabels // {}) | length) == 0) | select(.spec.mtls.mode == "STRICT")] | length > 0' >/dev/null \
  || { echo "❌ No PeerAuthentication in istio-system without a selector requires mtls mode STRICT (mesh-wide policy)"; exit 1; }

echo "✅ A mesh-wide PeerAuthentication in istio-system requires STRICT mTLS"
exit 0
