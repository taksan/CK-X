#!/bin/bash
# Effective kubelet configuration of node01: protectKernelDefaults true (and the node still healthy)

source "$(dirname "$0")/../lib/nodes.sh"
NODE="${NODE01}"
CFG=$(kubectl get --raw "/api/v1/nodes/$NODE/proxy/configz" 2>/dev/null || true)
[ -n "$CFG" ] || { echo "❌ Could not read the kubelet configuration of $NODE (is the node Ready and the kubelet running?)"; exit 1; }

V=$(echo "$CFG" | jq -r '.kubeletconfig.protectKernelDefaults // false')
[ "$V" = "true" ] || { echo "❌ The kubelet of $NODE has protectKernelDefaults=$V, expected true"; exit 1; }
[ "$(kubectl get node "$NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)" = "True" ] || { echo "❌ Node $NODE is not Ready"; exit 1; }

echo "✅ The kubelet of ${NODE01} protects the kernel defaults"
exit 0
