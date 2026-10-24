#!/bin/bash
# Validate the AppArmor profile k8s-deny-write is loaded in the kernel of the first worker node

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$NODE01"
PROFILE="k8s-deny-write"

if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 "$NODE" "true" >/dev/null 2>&1; then
  echo "❌ Cannot reach $NODE over ssh"
  exit 1
fi

if ! ssh -o StrictHostKeyChecking=no "$NODE" "grep -q '^$PROFILE ' /sys/kernel/security/apparmor/profiles" >/dev/null 2>&1; then
  echo "❌ AppArmor profile '$PROFILE' is not loaded on $NODE (apparmor_parser -q /etc/apparmor.d/deny-tmp-write)"
  exit 1
fi

echo "✅ AppArmor profile '$PROFILE' is loaded on $NODE"
exit 0
