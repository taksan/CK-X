#!/bin/bash

# Setup for CKS-003 Question 5: NetworkPolicy restricted-policy
#
# Two namespaces, both exclusive to this question:
#   dev-team  products-service (the Pod to protect) and a peer Pod
#   qa-team   a Pod labelled environment=testing and one that is not
# Without a policy everything can reach products-service.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace dev-team
ensure_namespace qa-team

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: products-service
  namespace: dev-team
  labels:
    app: products-service
spec:
  containers:
  - name: web
    image: nginx:1.27-alpine
---
apiVersion: v1
kind: Pod
metadata:
  name: orders-client
  namespace: dev-team
  labels:
    app: orders-client
spec:
  containers:
  - name: client
    image: busybox:1.36.1
    command: ["sh", "-c", "sleep 36000"]
---
apiVersion: v1
kind: Pod
metadata:
  name: tester
  namespace: qa-team
  labels:
    environment: testing
spec:
  containers:
  - name: client
    image: busybox:1.36.1
    command: ["sh", "-c", "sleep 36000"]
---
apiVersion: v1
kind: Pod
metadata:
  name: visitor
  namespace: qa-team
  labels:
    environment: staging
spec:
  containers:
  - name: client
    image: busybox:1.36.1
    command: ["sh", "-c", "sleep 36000"]
EOF

echo "Setup completed for CKS-003 Question 5 (namespaces dev-team and qa-team)"
exit 0
