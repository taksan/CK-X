#!/bin/bash
# Behaviour: admin-pod (role=admin) still reaches the API on port 443 of the Service while
# restricted-pod does not (credited together, otherwise this check passes before any work is done)

source "$(dirname "$0")/../lib/q8-lib.sh"
init_q8 || exit 1
restricted_blocked || { echo "❌ $BLOCK_REASON (nothing to credit for admin-pod yet)"; exit 1; }

CODE=$(api_code admin-pod "$CLUSTER_URL")
[ "$CODE" != "000" ] || { echo "❌ admin-pod cannot reach the Kubernetes API through the Service address ($CLUSTER_URL): the pods labelled role=admin must still be allowed (the network plugin applies the policy to the real API address: kubectl get endpoints kubernetes)"; exit 1; }

echo "✅ admin-pod reaches the Kubernetes API (HTTP $CODE) while restricted-pod does not"
exit 0
