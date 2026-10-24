#!/bin/bash
# Validate the Pod manifest: container runs as UID 5375, not privileged, no privilege escalation

WORKDIR="${Q3_WORKDIR:-/tmp/exam/cks-002-q3}"
POD_PATH="$WORKDIR/pod.yaml"

if [ ! -f "$POD_PATH" ]; then
  echo "❌ Pod manifest not found at $POD_PATH"
  exit 1
fi

JSON=$(kubectl create --dry-run=client --validate=false -f "$POD_PATH" -o json 2>/dev/null)
if [ -z "$JSON" ]; then
  echo "❌ The Pod manifest is not valid YAML/Kubernetes"
  exit 1
fi

# effective UID of the first container: container level overrides pod level
UID_EFFECTIVE=$(echo "$JSON" | jq -r '(.spec.containers[0].securityContext.runAsUser // .spec.securityContext.runAsUser // "unset") | tostring')
if [ "$UID_EFFECTIVE" != "5375" ]; then
  echo "❌ The container runs as UID '$UID_EFFECTIVE', expected 5375"
  exit 1
fi

# no root anywhere
if echo "$JSON" | jq -e '[.spec.securityContext.runAsUser, (.spec.containers[]? | .securityContext.runAsUser)] | map(select(. == 0)) | length > 0' >/dev/null; then
  echo "❌ Pod manifest still sets runAsUser: 0 (root)"
  exit 1
fi

if echo "$JSON" | jq -e '[.spec.containers[]? | .securityContext.privileged] | any(. == true)' >/dev/null; then
  echo "❌ Pod manifest still has privileged: true"
  exit 1
fi

if ! echo "$JSON" | jq -e '[.spec.containers[]? | .securityContext.allowPrivilegeEscalation] | all(. == false)' >/dev/null; then
  echo "❌ allowPrivilegeEscalation must stay false"
  exit 1
fi

echo "✅ Container runs as UID 5375, is not privileged and cannot escalate privileges"
exit 0
