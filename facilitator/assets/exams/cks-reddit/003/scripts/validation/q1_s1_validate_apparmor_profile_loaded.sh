#!/bin/bash
# Validate the AppArmor profile nginx-deny is loaded on node02

NODE="node02"
PROFILE="nginx-deny"

if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 "$NODE" "true" >/dev/null 2>&1; then
  echo "❌ Cannot reach $NODE over ssh"
  exit 1
fi

if ! ssh -o StrictHostKeyChecking=no "$NODE" "grep -q '^$PROFILE ' /sys/kernel/security/apparmor/profiles" >/dev/null 2>&1; then
  echo "❌ AppArmor profile '$PROFILE' is not loaded on $NODE"
  exit 1
fi

echo "✅ AppArmor profile '$PROFILE' is loaded on $NODE"
exit 0
