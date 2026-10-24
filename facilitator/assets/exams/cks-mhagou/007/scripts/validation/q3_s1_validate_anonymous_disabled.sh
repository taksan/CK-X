#!/bin/bash
# Item: the kubelet of node02 does not accept anonymous requests (effective configuration and behaviour)
source "$(dirname "$0")/../lib/nodes.sh"

for i in $(seq 1 20); do
  CFG=$(kubectl get --raw /api/v1/nodes/$NODE02/proxy/configz 2>/dev/null)
  [ -n "$CFG" ] && break
  sleep 3
done
[ -n "$CFG" ] || { echo "❌ Unable to read the effective kubelet configuration of $NODE02 (is the kubelet running?)"; exit 1; }

ANON=$(echo "$CFG" | jq -r '.kubeletconfig.authentication.anonymous.enabled')
[ "$ANON" = "false" ] || { echo "❌ The kubelet of $NODE02 runs with authentication.anonymous.enabled=$ANON, expected false"; exit 1; }

IP=$(kubectl get node "$NODE02" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
CODE=$(curl -sk -m 8 -o /dev/null -w '%{http_code}' "https://$IP:10250/pods")
[ "$CODE" = "401" ] || { echo "❌ An anonymous request to the kubelet API of $NODE02 returns HTTP $CODE, expected 401"; exit 1; }

echo "✅ The kubelet of $NODE02 rejects anonymous requests (effective anonymous.enabled=false, HTTP 401)"
exit 0
