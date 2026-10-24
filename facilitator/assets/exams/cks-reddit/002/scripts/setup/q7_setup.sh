#!/bin/bash

# Setup for CKS-002 Question 7: AppArmor profile on node01

set -euo pipefail

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

# Prepare AppArmor profile file on node01 without modifying existing files
ssh -o StrictHostKeyChecking=no node01 'bash -s' <<'EOF'
set -euo pipefail
PROFILE_PATH="/etc/apparmor.d/nginx_apparmor"

if [ ! -f "$PROFILE_PATH" ]; then
  cat >"$PROFILE_PATH" <<'PROFILE'
#include <tunables/global>
profile nginx-profile-2 flags=(attach_disconnected) {
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

# The Pod lives in its own namespace, so it cannot clash with the nginx-pod of Q2
ensure_namespace apparmor
kubectl delete pod apparmor-pod -n apparmor --ignore-not-found >/dev/null 2>&1 || true

# Manifest the candidate has to update. busybox is used on purpose: the profile
# denies every write, which an nginx container cannot survive.
WORKDIR="/tmp/exam/cks-002-q7"
mkdir -p "$WORKDIR"
cat > "$WORKDIR/pod.yaml" <<MANIFEST
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-pod
  namespace: apparmor
spec:
  nodeName: $NODE01
  containers:
  - name: busybox
    image: busybox:1.36.1
    command: ["sh", "-c", "sleep 3600"]
MANIFEST

echo "Setup completed for CKS-002 Question 7 (AppArmor on $NODE01)"
exit 0
