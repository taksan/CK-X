#!/bin/bash

# Setup for MHagou CKS exam 9, Question 7: monitor ONE container of a Pod with Falco.
# Namespace web-tier is exclusive. The Pod nginx (on the second worker node) has two containers: nginx, which keeps
# running /bin/ls, and log-agent, a sidecar that keeps running /bin/hostname. Both binaries are already
# in the images (a binary created at run time would be hidden by Falco's default drift rule).

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

NS="web-tier"
DIR="/tmp/exam/mhagou-009-q7"
ensure_namespace "$NS"

ssh -o StrictHostKeyChecking=no "$NODE02" "mkdir -p $DIR && rm -f ${DIR:?}/* && date -u +%Y-%m-%dT%H:%M:%S > $DIR/.started"

kubectl delete pod nginx -n "$NS" --ignore-not-found --now >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  namespace: ${NS}
spec:
  nodeName: ${NODE02}
  containers:
  - name: nginx
    image: nginx:stable-alpine
    command: ["/bin/sh", "-c"]
    args:
    - |
      (while :; do /bin/ls /tmp > /dev/null; sleep 1; done) &
      exec nginx -g 'daemon off;'
  - name: log-agent
    image: busybox:1.36.1
    command: ["sh", "-c", "while :; do /bin/hostname > /dev/null; sleep 1; done"]
EOF

echo "Setup completed for MHagou exam 9 Question 7 (namespace '$NS', report directory $DIR on $NODE02)"
exit 0
