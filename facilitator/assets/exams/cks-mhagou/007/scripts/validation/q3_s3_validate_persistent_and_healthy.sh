#!/bin/bash
# Item: the settings are in the kubelet configuration file (they survive a restart) and node02 is Ready
source "$(dirname "$0")/../lib/nodes.sh"

R=$(ssh -o StrictHostKeyChecking=no node02 "yq '.authentication.anonymous.enabled' /var/lib/kubelet/config.yaml; yq '.authorization.mode' /var/lib/kubelet/config.yaml; systemctl is-active kubelet" 2>/dev/null)
[ "$(echo "$R" | sed -n 1p)" = "false" ] || { echo "❌ /var/lib/kubelet/config.yaml of $NODE02 does not set authentication.anonymous.enabled: false (a restart would undo the change)"; exit 1; }
[ "$(echo "$R" | sed -n 2p)" = "Webhook" ] || { echo "❌ /var/lib/kubelet/config.yaml of $NODE02 does not set authorization.mode: Webhook (a restart would undo the change)"; exit 1; }
[ "$(echo "$R" | sed -n 3p)" = "active" ] || { echo "❌ The kubelet service of $NODE02 is not active"; exit 1; }

for i in $(seq 1 30); do
  [ "$(kubectl get node "$NODE02" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)" = "True" ] && break
  sleep 3
done
[ "$(kubectl get node "$NODE02" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)" = "True" ] || { echo "❌ $NODE02 is not Ready"; exit 1; }

echo "✅ The kubelet configuration file of $NODE02 is correct and the node is Ready"
exit 0
