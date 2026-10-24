#!/bin/bash
# Item: the ImagePolicyWebhook admission plugin is enabled in the API server manifest

source "$(dirname "$0")/../lib/imagepolicy.sh"
IPW_CMD=$(ssh -o StrictHostKeyChecking=no "$IPW_NODE" "yq -o=json '.spec.containers[0].command' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null)
[ -n "$IPW_CMD" ] || { echo "❌ Unable to read the kube-apiserver manifest on the control plane"; exit 1; }

PLUGINS=$(echo "$IPW_CMD" | jq -r '[.[] | select(startswith("--enable-admission-plugins="))] | last // empty' | cut -d= -f2-)
if ! echo ",$PLUGINS," | grep -q ',ImagePolicyWebhook,'; then
  echo "❌ ImagePolicyWebhook is not in --enable-admission-plugins (found: '${PLUGINS:-<flag missing>}')"
  exit 1
fi
echo "$IPW_CMD" | jq -e '[.[] | select(startswith("--admission-control-config-file="))] | length > 0' >/dev/null \
  || { echo "❌ The plugin is enabled but kube-apiserver has no --admission-control-config-file flag"; exit 1; }

echo "✅ ImagePolicyWebhook is enabled and configured with an admission configuration file"
exit 0
