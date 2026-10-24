#!/bin/bash

# Setup for CKS-003 Question 4: runtime monitoring with Falco on node02
#
# Namespace runtime-watch (exclusive to this question) with a workload pinned to node02
# that spawns a process (whoami, an applet already in the image) every few seconds. The binary must
# not be created at run time: Falco's default drift rule ("Executing binary not part of base image")
# would report it first and, with rule_matching: first, hide it from the rule of the candidate. The candidate watches
# node02 with Falco and records the newly spawned processes in a file on node02.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

NAMESPACE="runtime-watch"
DIR="/tmp/exam/cks-003-q4"

ensure_namespace "$NAMESPACE"

ssh -o StrictHostKeyChecking=no node02 "mkdir -p $DIR/alerts && rm -f ${DIR:?}/alerts/* && date -u +%Y-%m-%dT%H:%M:%S > $DIR/.started"

kubectl delete deployment beacon -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1 || true

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: beacon
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: beacon
  template:
    metadata:
      labels:
        app: beacon
    spec:
      nodeSelector:
        kubernetes.io/hostname: $NODE02
      containers:
      - name: worker
        image: busybox:1.36.1
        command: ["sh", "-c", "while true; do sleep 4; /bin/whoami > /dev/null; done"]
EOF

echo "Setup completed for CKS-003 Question 4 (namespace '$NAMESPACE', output directory $DIR/alerts on $NODE02)"
exit 0
