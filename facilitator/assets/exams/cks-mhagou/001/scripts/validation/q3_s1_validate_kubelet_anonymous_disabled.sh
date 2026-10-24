#!/bin/bash
# Item (by behaviour): the kubelet of node02 runs and its EFFECTIVE configuration has anonymous authentication
# disabled (read from the kubelet itself through the API server, whatever the way it was configured)
source "$(dirname "$0")/../lib/nodes.sh"

for i in $(seq 1 30); do
  [ "$(kubectl get node "$NODE02" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)" = "True" ] && break
  sleep 4
done
[ "$(kubectl get node "$NODE02" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)" = "True" ] || { echo "❌ $NODE02 is not Ready: is the kubelet running?"; exit 1; }

ANON=$(kubectl get --raw /api/v1/nodes/$NODE02/proxy/configz 2>/dev/null | jq -r '.kubeletconfig.authentication.anonymous.enabled' 2>/dev/null)
[ "$ANON" = "false" ] || { echo "❌ The effective anonymous authentication of the kubelet of $NODE02 is '${ANON:-unknown}', expected false"; exit 1; }

echo "✅ The kubelet of $NODE02 runs with anonymous authentication disabled"
exit 0
