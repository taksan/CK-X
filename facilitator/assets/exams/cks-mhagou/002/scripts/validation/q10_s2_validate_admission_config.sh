#!/bin/bash
# The admission configuration is fixed: implicit deny (defaultAllow false) and a kubeConfigFile that exists

CFG=$(ssh -o StrictHostKeyChecking=no k8s-api-server "yq -o=json '.' /etc/kubernetes/pki/admission_configuration.yaml" 2>/dev/null)
IP=$(echo "$CFG" | jq -c '[.plugins[]? | select(.name == "ImagePolicyWebhook") | .configuration.imagePolicy][0] // empty' 2>/dev/null)
[ -n "$IP" ] || { echo "❌ /etc/kubernetes/pki/admission_configuration.yaml has no ImagePolicyWebhook configuration"; exit 1; }

[ "$(echo "$IP" | jq -r '.defaultAllow')" = "false" ] || { echo "❌ defaultAllow must be false (implicit deny): when the backend cannot be reached the images must be denied"; exit 1; }
KC=$(echo "$IP" | jq -r '.kubeConfigFile')
ssh -o StrictHostKeyChecking=no k8s-api-server "test -f '$KC'" 2>/dev/null || { echo "❌ kubeConfigFile '$KC' does not exist on the control plane"; exit 1; }

echo "✅ The admission configuration denies by default and points to an existing kubeconfig ($KC)"
exit 0
