#!/bin/bash

# Setup for MHAGOU-008 Question 1: detect a rogue container with Falco.
# Namespace forensics-lab is exclusive. The Pod rogue-pod runs on node01 and its container
# snooper-container keeps reading a file named secret.txt from a hostPath directory of node01.
# The candidate writes /tmp/exam/mhagou-008-q1/catch-rogue.yaml (jumphost or node01).

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

NS="forensics-lab"
DIR="/tmp/exam/mhagou-008-q1"

ensure_namespace "$NS"
kubectl delete pod rogue-pod -n "$NS" --ignore-not-found --now >/dev/null 2>&1

mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/catch-rogue.yaml

ssh -o StrictHostKeyChecking=no node01 "mkdir -p '$DIR/data' && echo 'MHagou lab: harmless demonstration data only.' > '$DIR/data/secret.txt' && chmod 755 '$DIR' '$DIR/data' && chmod 644 '$DIR/data/secret.txt'"

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: rogue-pod
  namespace: ${NS}
spec:
  nodeName: ${NODE01}
  containers:
  - name: snooper-container
    image: busybox:1.36.1
    command: ["sh", "-c", "while true; do cat /data/secret.txt; sleep 3; done"]
    volumeMounts:
    - name: data-vol
      mountPath: /data
  volumes:
  - name: data-vol
    hostPath:
      path: ${DIR}/data
      type: Directory
EOF

kubectl wait --for=condition=Ready pod/rogue-pod -n "$NS" --timeout=180s >/dev/null || { echo "WARNING: rogue-pod is not ready"; exit 1; }

echo "Setup completed for MHAGOU-008 Question 1 (namespace '$NS', Pod on ${NODE01}, rule file $DIR/catch-rogue.yaml)"
exit 0
