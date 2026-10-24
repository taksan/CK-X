#!/bin/bash
# Item: the webhook kubeconfig used by the active configuration points to the scanner endpoint

source "$(dirname "$0")/../lib/imagepolicy.sh"
ipw_load || exit 1
[ -n "$IPW_KC" ] || { echo "❌ The active configuration has no kubeConfigFile"; exit 1; }

SERVER=$(ssh -o StrictHostKeyChecking=no "$IPW_NODE" "yq -o=json '.' '$IPW_KC'" 2>/dev/null | jq -r '. as $k | ($k["current-context"] // "") as $cc | ([$k.contexts[]? | select(.name == $cc) | .context.cluster][0]) as $cl | [$k.clusters[]? | select(.name == $cl) | .cluster.server][0] // empty')
[ -n "$SERVER" ] || { echo "❌ Unable to read the server of the webhook kubeconfig '$IPW_KC' (missing file or context?)"; exit 1; }

if [ "${SERVER%/}" != "https://wakanda.local:8081/image_policy" ]; then
  echo "❌ The webhook kubeconfig points to '$SERVER', expected https://wakanda.local:8081/image_policy"
  exit 1
fi

echo "✅ The webhook points to https://wakanda.local:8081/image_policy"
exit 0
