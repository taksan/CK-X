#!/bin/bash

# Setup for CKS-005 Question 3: ingress NetworkPolicy limited to the namespace and one port.
# Namespaces staging (the target) and staging-ext (the outsider) are exclusive to this question.
# The Pod web listens on 80 and 8080.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace staging
ensure_namespace staging-ext
kubectl delete networkpolicy allow-np -n staging --ignore-not-found >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: staging
  labels: {app: web}
spec:
  containers:
  - name: web
    image: busybox:1.36.1
    command: ["sh", "-c", "mkdir -p /www && echo ok > /www/index.html && httpd -p 8080 -h /www && exec httpd -f -p 80 -h /www"]
---
apiVersion: v1
kind: Pod
metadata:
  name: peer
  namespace: staging
  labels: {app: peer}
spec:
  containers:
  - name: peer
    image: busybox:1.36.1
    command: ["sleep", "86400"]
---
apiVersion: v1
kind: Pod
metadata:
  name: outsider
  namespace: staging-ext
  labels: {app: outsider}
spec:
  containers:
  - name: outsider
    image: busybox:1.36.1
    command: ["sleep", "86400"]
EOF

echo "Setup completed for CKS-005 Question 3 (namespaces staging and staging-ext)"
exit 0
