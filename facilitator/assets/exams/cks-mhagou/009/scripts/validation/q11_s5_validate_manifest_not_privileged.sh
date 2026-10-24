#!/bin/bash
# Item: the container is not privileged

source "$(dirname "$0")/../lib/manifest_q11.sh"
load_manifest || exit 1
P=$(echo "$M_JSON" | jq -r '.spec.containers[0].securityContext.privileged')
[ "$P" = "false" ] || { echo "❌ privileged is '$P', expected false"; exit 1; }
echo "✅ The container is not privileged"
exit 0
