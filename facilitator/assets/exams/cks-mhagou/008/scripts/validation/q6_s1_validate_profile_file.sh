#!/bin/bash
# Item: a valid JSON profile exists at /var/lib/kubelet/seccomp/profiles/block-debug.json on the
# node where secure-app runs

source "$(dirname "$0")/../lib/seccomp-q6.sh"

P=$(q6_profile)
[ -n "$P" ] || { echo "❌ $Q6_PROFILE does not exist on the node of the Pod (or is empty)"; exit 1; }
echo "$P" | jq -e 'type == "object" and has("defaultAction")' >/dev/null 2>&1 || { echo "❌ $Q6_PROFILE is not a valid seccomp profile (JSON object with defaultAction)"; exit 1; }

echo "✅ $Q6_PROFILE is a valid profile"
exit 0
