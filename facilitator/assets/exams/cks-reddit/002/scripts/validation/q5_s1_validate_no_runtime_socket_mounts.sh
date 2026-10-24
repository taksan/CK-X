#!/bin/bash
# Validate no pod in dev-ops mounts a container runtime socket from the host

NAMESPACE="dev-ops"

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "❌ Namespace '$NAMESPACE' not found"
  exit 1
fi

SOCKETS='(containerd\.sock|docker\.sock|crio\.sock|cri-dockerd\.sock)$'

# Every hostPath path and every mountPath of every pod that is not terminating,
# including init containers (old pods can linger briefly after a rollout)
PATHS=$(kubectl get pods -n "$NAMESPACE" -o json 2>/dev/null | jq -r '
  .items[] | select(.metadata.deletionTimestamp == null)
  | ([.spec.volumes[]?.hostPath.path // empty]
     + [(.spec.containers[]?, .spec.initContainers[]?) | .volumeMounts[]?.mountPath])
  | .[]')

if echo "$PATHS" | grep -Eq "$SOCKETS"; then
  echo "❌ A pod in '$NAMESPACE' still mounts a container runtime socket:"
  echo "$PATHS" | grep -E "$SOCKETS" | sort -u
  exit 1
fi

echo "✅ No pod in '$NAMESPACE' mounts a container runtime socket"
exit 0
