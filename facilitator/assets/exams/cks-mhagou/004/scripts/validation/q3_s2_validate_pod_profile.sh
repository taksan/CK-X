#!/bin/bash
# Validate Pod audit-pod runs on the second worker node with a Localhost seccomp profile whose file exists on the
# node, and that it can still create directories (the profile logs, it does not block)

source "$(dirname "$0")/../lib/nodes.sh"

NS="syscall-lab"
POD="audit-pod"

J=$(kubectl get pod "$POD" -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod '$POD' not found in namespace '$NS'"; exit 1; }
[ "$(echo "$J" | jq -r '.spec.nodeName')" = "$NODE02" ] || { echo "❌ Pod '$POD' does not run on $NODE02 (the profile is on $NODE02)"; exit 1; }

LOCAL=$(echo "$J" | jq -r '(.spec.containers[0].securityContext.seccompProfile // .spec.securityContext.seccompProfile // {}) | select(.type == "Localhost") | .localhostProfile // empty')
[ -n "$LOCAL" ] || { echo "❌ Pod '$POD' does not use a Localhost seccomp profile"; exit 1; }

ssh -o StrictHostKeyChecking=no "$NODE02" "test -f '/var/lib/kubelet/seccomp/$LOCAL'" 2>/dev/null \
  || { echo "❌ The profile '$LOCAL' of the Pod does not exist in /var/lib/kubelet/seccomp on $NODE02"; exit 1; }

[ "$(echo "$J" | jq -r '.status.phase')" = "Running" ] || { echo "❌ Pod '$POD' is not running (phase $(echo "$J" | jq -r '.status.phase'))"; exit 1; }

kubectl exec -n "$NS" "$POD" -- sh -c 'p=/tmp/ckx-seccomp-check-$$; mkdir "$p" && rmdir "$p"' >/dev/null 2>&1 \
  || { echo "❌ Creating a directory fails in the Pod: the profile must only log mkdir, not block it"; exit 1; }

echo "✅ Pod '$POD' runs on $NODE02 with the Localhost profile '$LOCAL' and mkdir works"
exit 0
