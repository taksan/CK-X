#!/bin/bash
# Validate the wiring on the control plane: plugin enabled (NodeRestriction kept), the admission
# configuration flag, a fail-closed configuration (defaultAllow false) and an existing kubeconfig.
# The manifest is read from the node: the mirror Pod can lag behind (it is itself admitted by the plugin).

CMD=$(ssh -o StrictHostKeyChecking=no k8s-api-server "yq -o=json '.spec.containers[0].command' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null | jq -c '.' 2>/dev/null)
[ -n "$CMD" ] || { echo "❌ Unable to read the kube-apiserver manifest on the control plane"; exit 1; }

PLUGINS=$(echo "$CMD" | grep -o -- '--enable-admission-plugins=[^"]*' | head -1 | cut -d= -f2)
echo ",$PLUGINS," | grep -q ',ImagePolicyWebhook,' || { echo "❌ ImagePolicyWebhook is not in --enable-admission-plugins"; exit 1; }
echo ",$PLUGINS," | grep -q ',NodeRestriction,' || { echo "❌ NodeRestriction was removed from --enable-admission-plugins: add the plugin, do not replace the list"; exit 1; }

FILE=$(echo "$CMD" | grep -o -- '--admission-control-config-file=[^"]*' | head -1 | cut -d= -f2)
[ -n "$FILE" ] || { echo "❌ kube-apiserver has no --admission-control-config-file flag"; exit 1; }

CFG=$(ssh -o StrictHostKeyChecking=no k8s-api-server "yq -o=json '.' '$FILE'" 2>/dev/null | jq -c '[.plugins[]? | select(.name == "ImagePolicyWebhook") | .configuration.imagePolicy][0] // empty' 2>/dev/null)
[ -n "$CFG" ] || { echo "❌ $FILE is missing or has no ImagePolicyWebhook configuration"; exit 1; }

[ "$(echo "$CFG" | jq -r '.defaultAllow')" = "false" ] || { echo "❌ defaultAllow must be false: when the backend cannot be reached the images must be denied"; exit 1; }
KC=$(echo "$CFG" | jq -r '.kubeConfigFile')
ssh -o StrictHostKeyChecking=no k8s-api-server "test -f '$KC'" 2>/dev/null || { echo "❌ kubeConfigFile '$KC' does not exist on the control plane"; exit 1; }

echo "✅ ImagePolicyWebhook is enabled (NodeRestriction kept), fail-closed, with an existing kubeconfig"
exit 0
