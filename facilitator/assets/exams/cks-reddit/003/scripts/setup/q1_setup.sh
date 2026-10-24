#!/bin/bash

# Setup for CKS-003 Question 1: AppArmor profile on node02
#
# Namespace profile-lab (exclusive to this question). The profile file is prepared on
# node02; the candidate loads it and updates the provided Pod manifest. busybox is used
# on purpose: the profile denies every write, which an nginx container cannot survive.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

NAMESPACE="profile-lab"
WORKDIR="/tmp/exam/cks-003-q1"

ssh -o StrictHostKeyChecking=no node02 'bash -s' <<'EOF'
set -euo pipefail
PROFILE_PATH="/etc/apparmor.d/nginx_apparmor"
if [ ! -f "$PROFILE_PATH" ]; then
  cat >"$PROFILE_PATH" <<'PROFILE'
#include <tunables/global>
profile nginx-deny flags=(attach_disconnected) {
    #include <abstractions/base>
    file,
    # The container runtime must be able to stop the container (SIGTERM/SIGKILL),
    # otherwise Pods using this profile can never be deleted.
    signal (receive) peer=runc,
    signal (receive) peer=unconfined,
    signal (receive) peer=cri-containerd.apparmor.d,
    # Deny all file writes.
    deny /** w,
}
PROFILE
fi
EOF

ensure_namespace "$NAMESPACE"
kubectl delete pod app-runner -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1 || true

mkdir -p "$WORKDIR"
cat > "$WORKDIR/pod.yaml" <<MANIFEST
apiVersion: v1
kind: Pod
metadata:
  name: app-runner
  namespace: profile-lab
spec:
  nodeName: $NODE02
  containers:
  - name: app
    image: busybox:1.36.1
    command: ["sh", "-c", "sleep 3600"]
MANIFEST

echo "Setup completed for CKS-003 Question 1 (namespace '$NAMESPACE', manifest in $WORKDIR)"
exit 0
