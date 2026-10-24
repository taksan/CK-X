#!/bin/bash
# Item: the AppArmor profile secure-profile is loaded on node01 in enforce mode
source "$(dirname "$0")/../lib/nodes.sh"

PROFILES=$(ssh -o StrictHostKeyChecking=no node01 'cat /sys/kernel/security/apparmor/profiles' 2>/dev/null)
[ -n "$PROFILES" ] || { echo "❌ Unable to read the loaded AppArmor profiles of $NODE01"; exit 1; }

if ! echo "$PROFILES" | grep -qE '^secure-profile \(enforce\)$'; then
  if echo "$PROFILES" | grep -q '^secure-profile '; then
    echo "❌ secure-profile is loaded on $NODE01 but not in enforce mode ($(echo "$PROFILES" | grep '^secure-profile ' | head -1))"
  else
    echo "❌ secure-profile is not loaded on $NODE01 (apparmor_parser -r /etc/apparmor.d/secure-profile)"
  fi
  exit 1
fi

echo "✅ secure-profile is loaded on $NODE01 in enforce mode"
exit 0
