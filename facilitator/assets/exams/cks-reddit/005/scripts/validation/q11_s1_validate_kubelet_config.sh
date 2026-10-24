#!/bin/bash
# Validate the kubelet of $NODE02 has seccompDefault enabled and is running: either the field in
# /var/lib/kubelet/config.yaml or the --seccomp-default flag of the running kubelet is accepted

source "$(dirname "$0")/../lib/nodes.sh"

R=$(ssh -o StrictHostKeyChecking=no node02 "yq '.seccompDefault' /var/lib/kubelet/config.yaml; systemctl is-active kubelet; pgrep -a kubelet | grep -cE -- '--seccomp-default(=true)?( |\$)'" 2>/dev/null)
CONFIG=$(echo "$R" | sed -n 1p); ACTIVE=$(echo "$R" | sed -n 2p); FLAG=$(echo "$R" | sed -n 3p)
[ "$ACTIVE" = "active" ] || { echo "❌ The kubelet of $NODE02 is not running"; exit 1; }
if [ "$CONFIG" != "true" ] && [ "${FLAG:-0}" -lt 1 ]; then
  echo "❌ seccompDefault is not enabled on $NODE02: neither 'seccompDefault: true' in /var/lib/kubelet/config.yaml nor the --seccomp-default flag of the running kubelet"
  exit 1
fi

echo "✅ The kubelet of $NODE02 has seccompDefault enabled"
exit 0
