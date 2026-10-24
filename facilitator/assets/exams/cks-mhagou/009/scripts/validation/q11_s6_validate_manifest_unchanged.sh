#!/bin/bash
# Item: no other setting of the manifest was added, removed or modified (credited once uid and privileged are fixed)

source "$(dirname "$0")/../lib/manifest_q11.sh"
load_manifest || exit 1
[ "$(echo "$M_JSON" | jq -r '.spec.containers[0].securityContext.runAsUser')" = "5487" ] && [ "$(echo "$M_JSON" | jq -r '.spec.containers[0].securityContext.privileged')" = "false" ] \
  || { echo "❌ not credited yet: fix runAsUser and privileged first"; exit 1; }

echo "$M_JSON" | jq -e '
  .apiVersion == "v1" and .kind == "Pod" and .metadata.name == "security-context-demo-2"
  and ((.spec.securityContext // {}) == {"runAsUser": 1000})
  and (.spec.containers | length == 1)
  and (.spec.containers[0] | .name == "sec-ctx-demo-2" and .image == "gcr.io/google-samples/node-hello:1.0"
       and ((.securityContext | del(.runAsUser, .privileged)) == {"allowPrivilegeEscalation": false})
       and ((del(.securityContext, .name, .image, .resources)) == {}))' >/dev/null \
  || { echo "❌ A setting of the manifest other than runAsUser/privileged was changed, added or removed"; exit 1; }

echo "✅ The other settings of the manifest are untouched"
exit 0
