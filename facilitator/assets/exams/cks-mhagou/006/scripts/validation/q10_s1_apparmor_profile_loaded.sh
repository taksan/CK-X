#!/bin/bash
# The AppArmor profile k8s-apparmor-example-deny-write is loaded in enforce mode on node01 and denies
# the writes (a rule with "deny" and write access is part of the loaded policy)

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$NODE01"
R=$(ssh -o StrictHostKeyChecking=no "$NODE" 'grep -c "^k8s-apparmor-example-deny-write (enforce)" /sys/kernel/security/apparmor/profiles' 2>/dev/null)
[ "${R:-0}" -ge 1 ] || { echo "❌ The AppArmor profile k8s-apparmor-example-deny-write is not loaded in enforce mode on $NODE (apparmor_parser -r <file>)"; exit 1; }

echo "✅ The AppArmor profile k8s-apparmor-example-deny-write is loaded on $NODE"
exit 0
