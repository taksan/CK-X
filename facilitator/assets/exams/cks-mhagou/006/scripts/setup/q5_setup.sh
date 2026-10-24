#!/bin/bash

# Setup for MHagou-006 Question 5: Falco capture of the processes of ONE nginx container.
# Namespace nginx-watch is exclusive. Two Pods (nginx) run on node02; web-1 keeps running uname and
# web-2 keeps running hostname (applets already in the image: no run-time binary that Falco's default
# drift rule would report first; in nginx:alpine whoami/uptime/id are reported as "sh" by Falco, uname and hostname by their name). The capture file is written on node02 under /tmp/exam/mhagou-006-q5
# (wiped by the node restore).

source "$(dirname "$0")/../lib/nodes.sh"

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="nginx-watch"
DIR="/tmp/exam/mhagou-006-q5"
ensure_namespace "$NS"

ssh -o StrictHostKeyChecking=no node02 "mkdir -p $DIR && rm -f ${DIR:?}/* && date -u +%Y-%m-%dT%H:%M:%S > $DIR/.started"

kubectl delete pod web-1 web-2 -n "$NS" --ignore-not-found --now >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata: {name: web-1, namespace: ${NS}, labels: {app: web}}
spec:
  nodeName: ${NODE02}
  containers:
  - name: nginx
    image: nginx:1.27-alpine
    command: ["sh", "-c", "nginx; while true; do sleep 3; /bin/uname > /dev/null; done"]
---
apiVersion: v1
kind: Pod
metadata: {name: web-2, namespace: ${NS}, labels: {app: web}}
spec:
  nodeName: ${NODE02}
  containers:
  - name: nginx
    image: nginx:1.27-alpine
    command: ["sh", "-c", "nginx; while true; do sleep 3; /bin/hostname > /dev/null; done"]
EOF

echo "Setup completed for MHagou-006 Question 5 (namespace '$NS', Pods on ${NODE02}, capture file under $DIR on ${NODE02})"
exit 0
