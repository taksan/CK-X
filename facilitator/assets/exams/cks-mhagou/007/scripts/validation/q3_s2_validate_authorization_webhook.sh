#!/bin/bash
# Item: the kubelet of node02 delegates the authorization to the API server (effective configuration)
source "$(dirname "$0")/../lib/nodes.sh"

for i in $(seq 1 20); do
  CFG=$(kubectl get --raw /api/v1/nodes/$NODE02/proxy/configz 2>/dev/null)
  [ -n "$CFG" ] && break
  sleep 3
done
[ -n "$CFG" ] || { echo "❌ Unable to read the effective kubelet configuration of $NODE02 (is the kubelet running?)"; exit 1; }

MODE=$(echo "$CFG" | jq -r '.kubeletconfig.authorization.mode')
[ "$MODE" = "Webhook" ] || { echo "❌ The kubelet of $NODE02 runs with authorization.mode=$MODE, expected Webhook"; exit 1; }
[ "$(echo "$CFG" | jq -r '.kubeletconfig.authentication.webhook.enabled')" = "true" ] \
  || { echo "❌ authentication.webhook.enabled must stay true (the API server authenticates its own requests with it)"; exit 1; }

echo "✅ The kubelet of $NODE02 uses authorization.mode=Webhook"
exit 0
