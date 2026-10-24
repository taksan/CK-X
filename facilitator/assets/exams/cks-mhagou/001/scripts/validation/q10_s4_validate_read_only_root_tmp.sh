#!/bin/bash
# Item (by behaviour): the root filesystem of immutable-pod is read-only, /tmp is a writable emptyDir

NS="vault-lab"
J=$(kubectl get pod immutable-pod -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'immutable-pod' not found in namespace '$NS'"; exit 1; }

echo "$J" | jq -e 'all(.spec.containers[]; .securityContext.readOnlyRootFilesystem == true)' >/dev/null \
  || { echo "❌ readOnlyRootFilesystem is not true for every container of the Pod"; exit 1; }

MOUNTS=$(kubectl exec -n "$NS" immutable-pod -- cat /proc/mounts 2>/dev/null)
echo "$MOUNTS" | awk '$2 == "/" {print $4}' | grep -qE '(^|,)ro(,|$)' || { echo "❌ The root filesystem of the running container is writable"; exit 1; }

VOL=$(echo "$J" | jq -r '[.spec.containers[].volumeMounts[]? | select(.mountPath == "/tmp")][0].name // empty')
[ -n "$VOL" ] || { echo "❌ Nothing is mounted at /tmp"; exit 1; }
echo "$J" | jq -e --arg v "$VOL" 'any(.spec.volumes[]?; .name == $v and has("emptyDir"))' >/dev/null || { echo "❌ /tmp is not backed by an emptyDir volume"; exit 1; }

kubectl exec -n "$NS" immutable-pod -- sh -c 'echo ok > /tmp/ckx-write-test && rm -f /tmp/ckx-write-test' >/dev/null 2>&1 || { echo "❌ The container cannot write to /tmp"; exit 1; }

echo "✅ The root filesystem is read-only and /tmp is a writable emptyDir"
exit 0
