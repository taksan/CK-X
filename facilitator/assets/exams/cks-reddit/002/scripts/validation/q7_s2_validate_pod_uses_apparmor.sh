#!/bin/bash
# Validate that Pod apparmor-pod (namespace apparmor) runs on node01 with the nginx-profile-2 AppArmor profile enforced

source "$(dirname "$0")/../lib/nodes.sh"

NAMESPACE="apparmor"
POD_NAME="apparmor-pod"
PROFILE_NAME="nginx-profile-2"

if ! kubectl get pod "$POD_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "❌ Pod '$POD_NAME' not found in namespace '$NAMESPACE'"
  exit 1
fi

NODE_NAME=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.nodeName}')
if [ "$NODE_NAME" != "$NODE01" ]; then
  echo "❌ Pod '$POD_NAME' is not scheduled on $NODE01 (current node: $NODE_NAME)"
  exit 1
fi

# Effective profile of the first container: container level overrides pod level;
# the pre-1.30 annotation is still accepted.
POD_JSON=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json)
CONTAINER=$(echo "$POD_JSON" | jq -r '.spec.containers[0].name')
LOCAL_PROFILE=$(echo "$POD_JSON" | jq -r --arg c "$CONTAINER" '
  ( .spec.containers[0].securityContext.appArmorProfile
    // .spec.securityContext.appArmorProfile
    | select(.type == "Localhost") | .localhostProfile )
  // ( .metadata.annotations["container.apparmor.security.beta.kubernetes.io/" + $c] // "" | sub("^localhost/"; "") )
  // ""')

if [ -z "$LOCAL_PROFILE" ]; then
  echo "❌ Pod '$POD_NAME' does not appear to have an AppArmor profile configured"
  exit 1
fi

if [ "$LOCAL_PROFILE" != "$PROFILE_NAME" ]; then
  echo "❌ Pod '$POD_NAME' does not use AppArmor profile '$PROFILE_NAME' (detected: $LOCAL_PROFILE)"
  exit 1
fi

PHASE=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
if [ "$PHASE" != "Running" ]; then
  echo "❌ Pod '$POD_NAME' is not running (phase: $PHASE); is the profile loaded on $NODE01?"
  exit 1
fi

# the profile denies all writes: creating a file must fail
if kubectl exec "$POD_NAME" -n "$NAMESPACE" -- touch /tmp/apparmor-write-test >/dev/null 2>&1; then
  echo "❌ Pod '$POD_NAME' can write to the filesystem: the profile is not enforced"
  exit 1
fi

echo "✅ Pod '$POD_NAME' on $NODE_NAME runs with AppArmor profile '$PROFILE_NAME' enforced"
exit 0
