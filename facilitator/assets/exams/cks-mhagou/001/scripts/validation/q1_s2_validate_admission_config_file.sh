#!/bin/bash
# Item: the admission configuration the API server uses configures ImagePolicyWebhook fail-closed
# (defaultAllow false) with an existing webhook kubeconfig, and the directory is mounted into the API server

source "$(dirname "$0")/../lib/apiserver.sh"

FILE=$(apiserver_flag admission-control-config-file)
[ -n "$FILE" ] || { echo "❌ kube-apiserver has no --admission-control-config-file flag"; exit 1; }

CFG=$(ssh -o StrictHostKeyChecking=no "$APISERVER_NODE" "yq -o=json '.' '$FILE'" 2>/dev/null)
[ -n "$CFG" ] || { echo "❌ $FILE does not exist on the control plane or is not valid YAML"; exit 1; }
IP=$(echo "$CFG" | jq -c '[.plugins[]? | select(.name == "ImagePolicyWebhook") | .configuration.imagePolicy][0] // empty')
[ -n "$IP" ] || { echo "❌ $FILE has no ImagePolicyWebhook configuration"; exit 1; }

[ "$(echo "$IP" | jq -r '.defaultAllow')" = "false" ] || { echo "❌ defaultAllow must be false: images are denied when the webhook cannot be reached (found: $(echo "$IP" | jq -r '.defaultAllow'))"; exit 1; }
KC=$(echo "$IP" | jq -r '.kubeConfigFile // empty')
[ -n "$KC" ] || { echo "❌ kubeConfigFile is not set in the ImagePolicyWebhook configuration"; exit 1; }
ssh -o StrictHostKeyChecking=no "$APISERVER_NODE" "test -f '$KC'" 2>/dev/null || { echo "❌ kubeConfigFile '$KC' does not exist on the control plane"; exit 1; }

V=$(apiserver_manifest_volumes)
if ! echo "$V" | jq -e --arg f "$FILE" --arg k "$KC" '
    . as $all
    | [($all.mounts // [])[] | select(. as $m | ($f, $k) as $p | $m.mountPath == $p or ($p | startswith($m.mountPath + "/"))) | .name] as $names
    | ($names | length) > 0
      and any(($all.volumes // [])[]; (.name as $n | $names | index($n) != null) and has("hostPath"))' >/dev/null 2>&1; then
  echo "❌ The directory of $FILE and $KC is not mounted into the kube-apiserver container (hostPath volume + volumeMount)"
  exit 1
fi

echo "✅ $FILE configures ImagePolicyWebhook with defaultAllow false and kubeConfigFile $KC; the directory is mounted"
exit 0
