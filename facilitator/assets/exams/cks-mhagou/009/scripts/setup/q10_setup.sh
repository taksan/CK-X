#!/bin/bash

# Setup for MHagou CKS exam 9, Question 10: a deny-all NetworkPolicy.
# Namespaces testing (the target: Pods server and client) and testing-ext (Pod outsider) are exclusive.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace testing
ensure_namespace testing-ext
kubectl delete networkpolicy --all -n testing >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata: {name: server, namespace: testing, labels: {app: server}}
spec:
  containers:
  - name: web
    image: busybox:1.36.1
    command: ["sh", "-c", "mkdir -p /www && echo ok > /www/index.html && exec httpd -f -p 80 -h /www"]
---
apiVersion: v1
kind: Pod
metadata: {name: client, namespace: testing, labels: {app: client}}
spec:
  containers:
  - name: client
    image: busybox:1.36.1
    command: ["sleep", "86400"]
---
apiVersion: v1
kind: Pod
metadata: {name: outsider, namespace: testing-ext, labels: {app: outsider}}
spec:
  containers:
  - name: web
    image: busybox:1.36.1
    command: ["sh", "-c", "mkdir -p /www && echo ok > /www/index.html && exec httpd -f -p 80 -h /www"]
EOF

echo "Setup completed for MHagou exam 9 Question 10 (namespaces testing and testing-ext)"
exit 0
