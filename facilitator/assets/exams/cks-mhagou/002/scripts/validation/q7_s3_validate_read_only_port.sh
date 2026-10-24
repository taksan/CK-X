#!/bin/bash
# Effective kubelet configuration of node01: read-only port 0 (disabled), nothing listens on 10255

source "$(dirname "$0")/../lib/nodes.sh"
NODE="${NODE01}"
CFG=$(kubectl get --raw "/api/v1/nodes/$NODE/proxy/configz" 2>/dev/null || true)
[ -n "$CFG" ] || { echo "❌ Could not read the kubelet configuration of $NODE (is the node Ready and the kubelet running?)"; exit 1; }

P=$(echo "$CFG" | jq -r '.kubeletconfig.readOnlyPort // 0')
[ "$P" = "0" ] || { echo "❌ The kubelet of $NODE has readOnlyPort=$P, expected 0"; exit 1; }
if ssh -o StrictHostKeyChecking=no "$NODE" "ss -ltn 'sport = :10255' | grep -q LISTEN" 2>/dev/null; then
  echo "❌ Something still listens on port 10255 of $NODE"
  exit 1
fi
[ "$(kubectl get node "$NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)" = "True" ] || { echo "❌ Node $NODE is not Ready"; exit 1; }

echo "✅ The read-only port of the kubelet of ${NODE01} is disabled"
exit 0
