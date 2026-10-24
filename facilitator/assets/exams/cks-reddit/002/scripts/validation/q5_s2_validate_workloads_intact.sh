#!/bin/bash
# Validate the affected Deployment was fixed (not deleted) and the unrelated one was left alone

NAMESPACE="dev-ops"
SOCKETS='(containerd\.sock|docker\.sock|crio\.sock|cri-dockerd\.sock)$'

JSON=$(kubectl get deployment billing -n "$NAMESPACE" -o json 2>/dev/null || true)
if [ -z "$JSON" ]; then
  echo "❌ Deployment 'billing' was deleted; it should be fixed instead"
  exit 1
fi

# the fix must be in the Deployment itself, not only in the running Pods
TEMPLATE_PATHS=$(echo "$JSON" | jq -r '
  ([.spec.template.spec.volumes[]?.hostPath.path // empty]
   + [(.spec.template.spec.containers[]?, .spec.template.spec.initContainers[]?) | .volumeMounts[]?.mountPath])
  | .[]')
if echo "$TEMPLATE_PATHS" | grep -Eq "$SOCKETS"; then
  echo "❌ Deployment 'billing' still mounts a container runtime socket"
  exit 1
fi

READY=$(echo "$JSON" | jq -r '.status.readyReplicas // 0')
if [ "$READY" = "0" ]; then
  echo "❌ Deployment 'billing' has no ready replicas"
  exit 1
fi

LOGPATH=$(kubectl get deployment notifier -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.volumes[*].hostPath.path}' 2>/dev/null || true)
if [ "$LOGPATH" != "/var/log" ]; then
  echo "❌ Deployment 'notifier' was modified or deleted (hostPath: '$LOGPATH')"
  exit 1
fi

echo "✅ 'billing' is running without the socket and 'notifier' was left untouched"
exit 0
