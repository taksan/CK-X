#!/bin/bash
# The AppArmor profile spectacleapp is loaded on node01

source "$(dirname "$0")/../lib/nodes.sh"
NODE="${NODE01}"
if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 "$NODE" "true" >/dev/null 2>&1; then
  echo "❌ Cannot reach $NODE over ssh"
  exit 1
fi
if ! ssh -o StrictHostKeyChecking=no "$NODE" "grep -q '^spectacleapp ' /sys/kernel/security/apparmor/profiles" >/dev/null 2>&1; then
  echo "❌ AppArmor profile 'spectacleapp' is not loaded on $NODE"
  exit 1
fi
echo "✅ AppArmor profile spectacleapp is loaded on ${NODE01}"
exit 0
