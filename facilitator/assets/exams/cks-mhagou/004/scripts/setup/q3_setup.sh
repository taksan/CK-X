#!/bin/bash

# Setup for MHagou-004 Question 3: a seccomp profile that logs mkdir, applied to a Pod on the second worker node.
# Namespace syscall-lab is exclusive to this question. The seccomp directory of the second worker node does not
# exist (the candidate creates it). A starter Pod runs on the second worker node without a profile; the candidate
# re-creates it from the supplied manifest with the profile.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

NS="syscall-lab"
DIR="/tmp/exam/mhagou-004-q3"

ssh -o StrictHostKeyChecking=no "$NODE02" 'rm -rf /var/lib/kubelet/seccomp'

ensure_namespace "$NS"
kubectl delete pod audit-pod -n "$NS" --ignore-not-found --now >/dev/null 2>&1

mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*
cat > "$DIR/pod.yaml" <<MANIFEST
apiVersion: v1
kind: Pod
metadata:
  name: audit-pod
  namespace: syscall-lab
  labels:
    app: audit-pod
spec:
  nodeName: $NODE02
  containers:
  - name: test-seccomp
    image: busybox:1.36.1
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      allowPrivilegeEscalation: false
MANIFEST

kubectl apply -f "$DIR/pod.yaml" >/dev/null

echo "Setup completed for MHagou-004 Question 3 (namespace '$NS', manifest $DIR/pod.yaml, Pod on $NODE02)"
exit 0
