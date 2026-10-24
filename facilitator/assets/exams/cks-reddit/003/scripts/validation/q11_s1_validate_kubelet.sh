#!/bin/bash
# Validate the live kubelet configuration of node02 (read from the kubelet itself)

source "$(dirname "$0")/../lib/nodes.sh"
NODE="$NODE02"

CFG=$(kubectl get --raw "/api/v1/nodes/$NODE/proxy/configz" 2>/dev/null || true)
if [ -z "$CFG" ]; then
  echo "❌ Could not read the kubelet configuration of $NODE (is the node Ready?)"
  exit 1
fi

ANON=$(echo "$CFG" | jq -r '.kubeletconfig.authentication.anonymous.enabled')
MODE=$(echo "$CFG" | jq -r '.kubeletconfig.authorization.mode')
RO_PORT=$(echo "$CFG" | jq -r '.kubeletconfig.readOnlyPort // 0')

[ "$ANON" = "false" ] || { echo "❌ kubelet on $NODE: anonymous authentication is not disabled (enabled=$ANON)"; exit 1; }
[ "$MODE" = "Webhook" ] || { echo "❌ kubelet on $NODE: authorization mode is '$MODE', expected Webhook"; exit 1; }
[ "$RO_PORT" = "0" ] || { echo "❌ kubelet on $NODE: read-only port is $RO_PORT, expected 0"; exit 1; }

echo "✅ kubelet on $NODE: anonymous auth disabled, Webhook authorization, read-only port disabled"
exit 0
