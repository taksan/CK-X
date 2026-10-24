#!/bin/bash

# Setup for MHagou-001 Question 2: AppArmor + seccomp + Pod Security Standards.
# Namespace secured-area is exclusive. The AppArmor profile secure-profile is prepared on node01 in
# /etc/apparmor.d (tracked by the node checkpoint: the restore unloads and removes it); the candidate loads
# it. The Pod manifest is a file for the candidate to complete. nginx runs through its binary (not the
# entrypoint script, which needs /bin/sh that the profile denies) and as the non-root user of the image.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

NS="secured-area"
DIR="/tmp/exam/mhagou-001-q2"

ensure_namespace "$NS"
kubectl label namespace "$NS" pod-security.kubernetes.io/enforce- >/dev/null 2>&1 || true
kubectl delete pod secure-nginx -n "$NS" --ignore-not-found --now >/dev/null 2>&1

ssh -o StrictHostKeyChecking=no node01 'bash -s' <<'EOF'
set -e
apparmor_parser -R /etc/apparmor.d/secure-profile >/dev/null 2>&1 || true
cat > /etc/apparmor.d/secure-profile <<'PROFILE'
#include <tunables/global>
profile secure-profile flags=(attach_disconnected) {
  #include <abstractions/base>
  file,
  # nginx must open its listening socket: newer kernels (AppArmor 4) mediate network access, older ones do not
  network,
  # the container runtime must be able to stop the container
  signal (receive) peer=runc,
  signal (receive) peer=unconfined,
  signal (receive) peer=cri-containerd.apparmor.d,
  deny /bin/sh mrwklx,
  # AppArmor matches the resolved path: the shell of an alpine/busybox image is /bin/busybox
  deny /bin/busybox mrwklx,
}
PROFILE
EOF

mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*
cat > "$DIR/secure-pod.yaml" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secure-nginx
  namespace: ${NS}
spec:
  nodeName: ${NODE01}
  containers:
  - name: nginx
    image: nginxinc/nginx-unprivileged:1.27-alpine
    command: ["nginx", "-g", "daemon off;"]
EOF

echo "Setup completed for MHagou-001 Question 2 (namespace '$NS', profile file on $NODE01, manifest $DIR/secure-pod.yaml)"
exit 0
