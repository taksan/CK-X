#!/bin/bash
# kube-apiserver enables ImagePolicyWebhook (keeping the other plugins) and loads the admission
# configuration /etc/kubernetes/pki/admission_configuration.yaml. The manifest is read on the
# control plane: the mirror Pod can lag behind (the kubelet needs the webhook to create it).

CMD=$(ssh -o StrictHostKeyChecking=no k8s-api-server "yq -o=json '.spec.containers[0].command' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null | jq -c '.' 2>/dev/null)
[ -n "$CMD" ] || { echo "❌ Unable to read the kube-apiserver manifest on the control plane"; exit 1; }

PLUGINS=$(echo "$CMD" | jq -r '.[] | select(startswith("--enable-admission-plugins="))' | head -1 | cut -d= -f2-)
echo ",$PLUGINS," | grep -q ',ImagePolicyWebhook,' || { echo "❌ ImagePolicyWebhook is not in --enable-admission-plugins"; exit 1; }
echo ",$PLUGINS," | grep -q ',NodeRestriction,' || { echo "❌ NodeRestriction was removed from --enable-admission-plugins: add the plugin, do not replace the list"; exit 1; }

FILE=$(echo "$CMD" | jq -r '.[] | select(startswith("--admission-control-config-file="))' | head -1 | cut -d= -f2-)
[ "$FILE" = "/etc/kubernetes/pki/admission_configuration.yaml" ] || { echo "❌ --admission-control-config-file is '${FILE:-<missing>}', expected /etc/kubernetes/pki/admission_configuration.yaml"; exit 1; }

echo "✅ kube-apiserver enables ImagePolicyWebhook and loads /etc/kubernetes/pki/admission_configuration.yaml"
exit 0
