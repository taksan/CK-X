#!/bin/bash
# Validate the Deployment manifest: not privileged, runs as 65535; nothing else changed

F="${Q10_DEPLOYMENT:-/tmp/exam/cks-004-q10/deployment.yaml}"
[ -f "$F" ] || { echo "❌ $F does not exist"; exit 1; }

J=$(kubectl create --dry-run=client -o json -f "$F" 2>/dev/null)
[ -n "$J" ] || { echo "❌ $F is not a valid manifest"; exit 1; }
C='.spec.template.spec.containers[0]'

[ "$(echo "$J" | jq -r "$C.securityContext.privileged")" = "false" ] || { echo "❌ The container is still privileged"; exit 1; }
[ "$(echo "$J" | jq -r "$C.securityContext.runAsUser")" = "65535" ] || { echo "❌ runAsUser must be 65535"; exit 1; }

# nothing else changed
echo "$J" | jq -e "$C.securityContext.readOnlyRootFilesystem == true and ($C.securityContext.capabilities.drop == [\"ALL\"]) and ($C.securityContext.capabilities.add == [\"NET_BIND_SERVICE\"]) and ($C.image == \"mysql:8.4\") and ($C.resources.limits.memory == \"512Mi\") and ($C.env | length == 1) and (.spec.template.spec.volumes | length == 1)" >/dev/null \
  || { echo "❌ Other settings were changed or removed: only existing insecure settings may be modified"; exit 1; }

echo "✅ Deployment: not privileged and running as 65535"
exit 0
