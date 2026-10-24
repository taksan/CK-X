#!/bin/bash

# Setup for MHagou CKS exam 9, Question 4: find a suspicious process with Falco.
# Namespace incident-lab is exclusive; both Pods run on the first worker node. api-gateway runs as uid 1000 and
# repeatedly executes /bin/nc (a netcat applet, an unusual process for a gateway) next to /bin/date;
# batch-runner is a harmless neighbour that executes /bin/hostname as root. Only binaries that are
# already in the image are executed (a binary created at run time would be reported first by
# Falco's default drift rule and hidden from a rule written by the candidate).

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

NS="incident-lab"
DIR="/tmp/exam/mhagou-009-q4"
ensure_namespace "$NS"

ssh -o StrictHostKeyChecking=no "$NODE01" "mkdir -p $DIR && rm -f ${DIR:?}/* && date -u +%Y-%m-%dT%H:%M:%S > $DIR/.started"

kubectl delete pod api-gateway batch-runner -n "$NS" --ignore-not-found --now >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: api-gateway
  namespace: ${NS}
spec:
  nodeName: ${NODE01}
  securityContext:
    runAsUser: 1000
  containers:
  - name: main
    image: busybox:1.36.1
    command: ["sh", "-c", "while true; do /bin/date > /dev/null; /bin/nc -w 1 198.51.100.7 4444 > /dev/null 2>&1; sleep 3; done"]
---
apiVersion: v1
kind: Pod
metadata:
  name: batch-runner
  namespace: ${NS}
spec:
  nodeName: ${NODE01}
  containers:
  - name: main
    image: busybox:1.36.1
    command: ["sh", "-c", "while true; do /bin/hostname > /dev/null; sleep 3; done"]
EOF

echo "Setup completed for MHagou exam 9 Question 4 (namespace '$NS', report directory $DIR on $NODE01)"
exit 0
