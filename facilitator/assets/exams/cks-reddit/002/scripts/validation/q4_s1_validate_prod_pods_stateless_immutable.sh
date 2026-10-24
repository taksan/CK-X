#!/bin/bash
# Validate prod: no remaining Pod is stateful or mutable, and the compliant Pods were kept

NAMESPACE="prod"
KEEP="catalog-api checkout"

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "❌ Namespace '$NAMESPACE' not found"
  exit 1
fi

PODS_JSON=$(kubectl get pods -n "$NAMESPACE" -o json 2>/dev/null)
if [ -z "$PODS_JSON" ]; then
  echo "❌ Could not list the Pods in '$NAMESPACE'"
  exit 1
fi

# Violations of the Pods that are not terminating. Stateful = a volume that holds data
# (emptyDir, hostPath, PVC, ephemeral); config-style volumes (configMap, secret, ...) are fine.
# Not immutable = a privileged container, or a root filesystem that is not read-only.
VIOLATIONS=$(echo "$PODS_JSON" | jq -r '
  .items[] | select(.metadata.deletionTimestamp == null)
  | .metadata.name as $n
  | ( (.spec.volumes // [])[] | select(.emptyDir or .hostPath or .persistentVolumeClaim or .ephemeral)
      | "\($n): stateful volume \"\(.name)\"" ),
    ( ((.spec.containers // []) + (.spec.initContainers // []))[]
      | select(.securityContext.privileged == true)
      | "\($n): container \"\(.name)\" is privileged" ),
    ( ((.spec.containers // []) + (.spec.initContainers // []))[]
      | select(.securityContext.readOnlyRootFilesystem != true)
      | "\($n): container \"\(.name)\" has a writable root filesystem" )')

if [ -n "$VIOLATIONS" ]; then
  echo "❌ Pods in '$NAMESPACE' are still stateful or not immutable:"
  echo "$VIOLATIONS" | sed 's/^/   /'
  exit 1
fi

# the compliant Pods must not have been deleted
for pod in $KEEP; do
  if ! echo "$PODS_JSON" | jq -e --arg p "$pod" '.items[] | select(.metadata.name == $p and .metadata.deletionTimestamp == null)' >/dev/null; then
    echo "❌ Pod '$pod' is compliant and should have been kept"
    exit 1
  fi
done

echo "✅ Only stateless, immutable Pods remain in '$NAMESPACE' and the compliant ones were kept"
exit 0
