#!/bin/bash
# Validate that AppArmor profile nginx-profile-2 exists and is loaded on node01

PROFILE_NAME="nginx-profile-2"
PROFILE_FILE="/etc/apparmor.d/nginx_apparmor"
NODE="node01"

# Check that we can reach the node
if ! ssh -o StrictHostKeyChecking=no "$NODE" "echo 1" >/dev/null 2>&1; then
  echo "❌ Unable to SSH to $NODE"
  exit 1
fi

# Check if AppArmor is installed
if ! ssh -o StrictHostKeyChecking=no "$NODE" "command -v apparmor_parser" >/dev/null 2>&1; then
  echo "❌ AppArmor is not installed on $NODE"
  exit 1
fi

# Check if AppArmor is enabled
if ! ssh -o StrictHostKeyChecking=no "$NODE" "grep -q 'Y' /sys/module/apparmor/parameters/enabled" >/dev/null 2>&1; then
  echo "❌ AppArmor is not enabled on $NODE"
  exit 1
fi

# Check if the profile file exists
if ! ssh -o StrictHostKeyChecking=no "$NODE" "[ -f '$PROFILE_FILE' ]" >/dev/null 2>&1; then
  echo "❌ AppArmor profile file not found at $PROFILE_FILE on $NODE"
  exit 1
fi

# Check if the profile is loaded
if ! ssh -o StrictHostKeyChecking=no "$NODE" "grep -q '$PROFILE_NAME' /sys/kernel/security/apparmor/profiles" >/dev/null 2>&1; then
  echo "❌ AppArmor profile '$PROFILE_NAME' is not loaded on $NODE"
  exit 1
fi

echo "✅ AppArmor profile '$PROFILE_NAME' exists and is loaded on $NODE"
exit 0
