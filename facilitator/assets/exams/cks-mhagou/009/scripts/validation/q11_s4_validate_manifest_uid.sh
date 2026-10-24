#!/bin/bash
# Item: the container of the manifest runs as UID 5487

source "$(dirname "$0")/../lib/manifest_q11.sh"
load_manifest || exit 1
U=$(echo "$M_JSON" | jq -r '.spec.containers[0].securityContext.runAsUser')
[ "$U" = "5487" ] || { echo "❌ The container runs as UID '$U', expected 5487"; exit 1; }
echo "✅ The container runs as UID 5487"
exit 0
