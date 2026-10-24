#!/bin/bash
# Source this file (question 6). Reads the API server manifest and the active ImagePolicyWebhook files on the control plane.
#   ipw_load      sets IPW_CMD (JSON array of the API server command), IPW_CFG (imagePolicy section) and
#                 IPW_KC (kubeconfig path of the configuration); returns 1 with a message when something is missing
IPW_NODE="k8s-api-server"

ipw_load() {
  IPW_CMD=$(ssh -o StrictHostKeyChecking=no "$IPW_NODE" "yq -o=json '.spec.containers[0].command' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null)
  [ -n "$IPW_CMD" ] || { echo "❌ Unable to read the kube-apiserver manifest on the control plane"; return 1; }
  local file
  file=$(echo "$IPW_CMD" | jq -r '[.[] | select(startswith("--admission-control-config-file="))] | last // empty' | cut -d= -f2-)
  [ -n "$file" ] || { echo "❌ kube-apiserver has no --admission-control-config-file flag"; return 1; }
  IPW_CFG=$(ssh -o StrictHostKeyChecking=no "$IPW_NODE" "yq -o=json '.' '$file'" 2>/dev/null | jq -c '[.plugins[]? | select(.name == "ImagePolicyWebhook") | .configuration.imagePolicy][0] // empty' 2>/dev/null)
  [ -n "$IPW_CFG" ] || { echo "❌ $file is missing or has no ImagePolicyWebhook configuration"; return 1; }
  IPW_KC=$(echo "$IPW_CFG" | jq -r '.kubeConfigFile // empty')
}
