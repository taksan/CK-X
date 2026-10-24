#!/bin/bash

# Setup for MHAGOU-002 Question 1: delete the Pods that run images with CRITICAL vulnerabilities.
# Namespace spectacle is exclusive to this question. Four Pods (no controller recreates them):
#   atlas   nginx:1.16        CRITICAL findings   (to delete)
#   beacon  httpd:2.4.49      CRITICAL findings   (to delete)
#   comet   redis:7.2-alpine  HIGH findings only  (to keep: the question is about CRITICAL)
#   delta   busybox:1.36.1    no findings         (to keep)
# The counts were measured with Trivy when the exam was written; the validators use the names.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="spectacle"
ensure_namespace "$NS"

kubectl delete pod atlas beacon comet delta -n "$NS" --ignore-not-found --now >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: atlas
  namespace: ${NS}
spec:
  containers:
  - name: workload
    image: nginx:1.16
---
apiVersion: v1
kind: Pod
metadata:
  name: beacon
  namespace: ${NS}
spec:
  containers:
  - name: workload
    image: httpd:2.4.49
---
apiVersion: v1
kind: Pod
metadata:
  name: comet
  namespace: ${NS}
spec:
  containers:
  - name: workload
    image: redis:7.2-alpine
---
apiVersion: v1
kind: Pod
metadata:
  name: delta
  namespace: ${NS}
spec:
  containers:
  - name: workload
    image: busybox:1.36.1
    command: ["sleep", "86400"]
EOF

echo "Setup completed for MHAGOU-002 Question 1 (namespace '$NS')"
exit 0
