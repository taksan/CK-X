#!/bin/bash

# Setup for CKS-005 Question 13: find the ServiceAccount of a Pod and grant it a Role.
# Namespace test-system is exclusive. nginx-pod uses sa-dev-1; sa-dev-2 is a decoy.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="test-system"
DIR="/tmp/exam/cks-005-q13"
ensure_namespace "$NS"
kubectl delete pod nginx-pod -n "$NS" --ignore-not-found --now >/dev/null 2>&1
kubectl delete role deploy-reader -n "$NS" --ignore-not-found >/dev/null 2>&1
kubectl delete rolebinding deploy-reader-bind -n "$NS" --ignore-not-found >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: ServiceAccount
metadata: {name: sa-dev-1, namespace: ${NS}}
---
apiVersion: v1
kind: ServiceAccount
metadata: {name: sa-dev-2, namespace: ${NS}}
---
apiVersion: v1
kind: Pod
metadata: {name: nginx-pod, namespace: ${NS}}
spec:
  serviceAccountName: sa-dev-1
  containers:
  - {name: nginx, image: nginx:1.27-alpine}
EOF

mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*
echo "Setup completed for CKS-005 Question 13 (namespace '$NS', output directory $DIR)"
exit 0
