#!/bin/bash

# Setup for MHagou-006 Question 2: a Falco rule for the reads of /tmp/mem. Namespace mem-watch is
# exclusive to this question. Three Deployments run on node01 (where the candidate edits the Falco
# service rules): compute-a and compute-b only sleep, compute-c keeps a small file /tmp/mem and
# reads it every 10 seconds (cat is an applet already in the image: no new binary is created).

source "$(dirname "$0")/../lib/nodes.sh"

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="mem-watch"
ensure_namespace "$NS"

kubectl apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata: {name: compute-a, namespace: ${NS}}
spec:
  replicas: 1
  selector: {matchLabels: {app: compute-a}}
  template:
    metadata: {labels: {app: compute-a}}
    spec:
      nodeSelector: {kubernetes.io/hostname: ${NODE01}}
      containers:
      - {name: main, image: "busybox:1.36.1", command: ["sh", "-c", "sleep 86400"]}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: compute-b, namespace: ${NS}}
spec:
  replicas: 1
  selector: {matchLabels: {app: compute-b}}
  template:
    metadata: {labels: {app: compute-b}}
    spec:
      nodeSelector: {kubernetes.io/hostname: ${NODE01}}
      containers:
      - {name: main, image: "busybox:1.36.1", command: ["sh", "-c", "sleep 86400"]}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: compute-c, namespace: ${NS}}
spec:
  replicas: 1
  selector: {matchLabels: {app: compute-c}}
  template:
    metadata: {labels: {app: compute-c}}
    spec:
      nodeSelector: {kubernetes.io/hostname: ${NODE01}}
      containers:
      - name: main
        image: busybox:1.36.1
        command:
        - sh
        - -c
        - |
          dd if=/dev/urandom of=/tmp/mem bs=1K count=4 2>/dev/null
          while true; do cat /tmp/mem > /dev/null; sleep 10; done
EOF

echo "Setup completed for MHagou-006 Question 2 (namespace '$NS', workloads on ${NODE01})"
exit 0
