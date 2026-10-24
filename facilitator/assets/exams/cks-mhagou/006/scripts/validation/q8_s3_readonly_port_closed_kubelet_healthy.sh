#!/bin/bash
# The read-only port 10255 of the control plane kubelet does not listen any more, the kubelet runs and
# the node is Ready

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$CONTROL_PLANE"
R=$(ssh -o StrictHostKeyChecking=no "$NODE" 'systemctl is-active kubelet; ss -ltn | grep -c ":10255 "; yq ".readOnlyPort // 0" /var/lib/kubelet/config.yaml' 2>/dev/null)

[ "$(echo "$R" | sed -n 2p)" = "0" ] || { echo "❌ Something still listens on port 10255 of the control plane (the read-only port is open)"; exit 1; }
[ "$(echo "$R" | sed -n 3p)" = "0" ] || { echo "❌ /var/lib/kubelet/config.yaml sets readOnlyPort $(echo "$R" | sed -n 3p), expected 0"; exit 1; }
[ "$(echo "$R" | sed -n 1p)" = "active" ] || { echo "❌ The kubelet service is not running on the control plane"; exit 1; }

READY=""
for i in $(seq 1 20); do
  READY=$(kubectl get node "$NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  [ "$READY" = "True" ] && break
  sleep 3
done
[ "$READY" = "True" ] || { echo "❌ The node $NODE is not Ready"; exit 1; }

echo "✅ The read-only port is closed, the kubelet runs and the node is Ready"
exit 0
