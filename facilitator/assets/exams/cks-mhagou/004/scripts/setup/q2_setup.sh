#!/bin/bash

# Setup for MHagou-004 Question 2: AppArmor profile that denies writes to /tmp on the first worker node.
# Namespace write-guard is exclusive to this question. The profile file is prepared on the first worker node in
# /etc/apparmor.d (a checkpointed path: the node restore unloads it); the candidate loads it and
# edits the supplied Pod manifest. busybox is used on purpose (the profile only denies /tmp writes).

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

NS="write-guard"
DIR="/tmp/exam/mhagou-004-q2"

ssh -o StrictHostKeyChecking=no "$NODE01" 'bash -s' <<'EOF'
set -e
cat > /etc/apparmor.d/deny-tmp-write <<'PROFILE'
#include <tunables/global>
profile k8s-deny-write flags=(attach_disconnected) {
  #include <abstractions/base>
  file,
  # The container runtime must be able to stop the container (SIGTERM/SIGKILL),
  # otherwise Pods using this profile can never be deleted.
  signal (receive) peer=runc,
  signal (receive) peer=unconfined,
  signal (receive) peer=cri-containerd.apparmor.d,
  # Deny all writes under /tmp.
  deny /tmp/** w,
}
PROFILE
EOF

ensure_namespace "$NS"
kubectl delete pod hello-apparmor -n "$NS" --ignore-not-found --now >/dev/null 2>&1

mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*
cat > "$DIR/pod.yaml" <<MANIFEST
apiVersion: v1
kind: Pod
metadata:
  name: hello-apparmor
  namespace: write-guard
spec:
  nodeName: $NODE01
  containers:
  - name: hello
    image: busybox:1.36.1
    command: ["sh", "-c", "echo 'Hello AppArmor!' && sleep 3600"]
MANIFEST

echo "Setup completed for MHagou-004 Question 2 (namespace '$NS', profile file on $NODE01, manifest $DIR/pod.yaml)"
exit 0
