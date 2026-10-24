#!/bin/bash

# Setup for MHagou-006 Question 10: kernel hardening on node01 (AppArmor and seccomp). Namespace
# kernel-lab is exclusive. On node01 (the candidate works there: ssh node01) the setup prepares a
# starter AppArmor profile (it protects nothing yet) and the seccomp profile directory. The Pod
# manifests are on the jumphost in /tmp/exam/mhagou-006-q10 (nothing is deployed).

source "$(dirname "$0")/../lib/nodes.sh"

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="kernel-lab"
DIR="/tmp/exam/mhagou-006-q10"
ensure_namespace "$NS"
kubectl delete pod hello-apparmor audit-pod -n "$NS" --ignore-not-found --now >/dev/null 2>&1

ssh -o StrictHostKeyChecking=no node01 'bash -s' <<'EOF'
set -e
mkdir -p /tmp/exam/mhagou-006-q10 /var/lib/kubelet/seccomp/profiles
cat > /tmp/exam/mhagou-006-q10/apparmor-profile <<'PROFILE'
#include <tunables/global>
profile k8s-apparmor-example-deny-write flags=(attach_disconnected) {
  #include <abstractions/base>
  file,
  network,
  capability,
  # the container runtime must be able to stop the container
  signal (receive) peer=runc,
  signal (receive) peer=unconfined,
  signal (receive) peer=cri-containerd.apparmor.d,
}
PROFILE
EOF
[ $? -eq 0 ] || { echo "Failed to prepare ${NODE01}"; exit 1; }

mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*
cat > "$DIR/hello-apparmor.yaml" <<MANIFEST
apiVersion: v1
kind: Pod
metadata:
  name: hello-apparmor
  namespace: ${NS}
spec:
  nodeName: ${NODE01}
  containers:
  - name: hello
    image: busybox:1.36.1
    command: ["sh", "-c", "echo 'Hello AppArmor!' && sleep 3600"]
MANIFEST
cat > "$DIR/audit-pod.yaml" <<MANIFEST
apiVersion: v1
kind: Pod
metadata:
  name: audit-pod
  namespace: ${NS}
  labels:
    app: audit-pod
spec:
  nodeName: ${NODE01}
  securityContext:
    seccompProfile:
      type: Unconfined
  containers:
  - name: test-container
    image: hashicorp/http-echo:1.0
    args: ["-text=just made some syscalls!"]
MANIFEST

echo "Setup completed for MHagou-006 Question 10 (namespace '$NS', starter profile on ${NODE01}, manifests in $DIR)"
exit 0
