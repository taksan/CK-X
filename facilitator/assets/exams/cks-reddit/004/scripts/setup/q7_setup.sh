#!/bin/bash

# Setup for CKS-004 Question 7: runtime monitoring of one Pod with Falco on node01.
# Namespace monitoring-lab is exclusive to this question. Two Pods run on node01 and each one
# spawns a process with its own name every few seconds: tomcat (to be monitored) and batch (noise,
# which must NOT end up in the report).

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

NAMESPACE="monitoring-lab"
DIR="/tmp/exam/cks-004-q7"

ensure_namespace "$NAMESPACE"

ssh -o StrictHostKeyChecking=no node01 "mkdir -p $DIR && rm -f ${DIR:?}/report && date -u +%Y-%m-%dT%H:%M:%S > $DIR/.started"

kubectl delete pod tomcat batch -n "$NAMESPACE" --ignore-not-found --now >/dev/null 2>&1

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: tomcat
  namespace: ${NAMESPACE}
spec:
  nodeName: $NODE01
  containers:
  - name: tomcat
    image: busybox:1.36.1
    command: ["sh", "-c", "while true; do sleep 4; /bin/whoami > /dev/null; done"]
---
apiVersion: v1
kind: Pod
metadata:
  name: batch
  namespace: ${NAMESPACE}
spec:
  nodeName: $NODE01
  containers:
  - name: batch
    image: busybox:1.36.1
    command: ["sh", "-c", "while true; do sleep 3; /bin/hostname > /dev/null; done"]
EOF

echo "Setup completed for CKS-004 Question 7 (namespace '$NAMESPACE', report directory $DIR on $NODE01)"
exit 0
