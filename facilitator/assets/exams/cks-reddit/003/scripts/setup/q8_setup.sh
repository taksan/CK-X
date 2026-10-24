#!/bin/bash

# Setup for CKS-003 Question 8: Pod Security + RBAC in the staging namespace (exclusive to
# this question). The namespace exists without any Pod Security label.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace staging
kubectl label namespace staging pod-security.kubernetes.io/enforce- pod-security.kubernetes.io/enforce-version- >/dev/null 2>&1 || true
kubectl delete serviceaccount deployer-sa -n staging --ignore-not-found >/dev/null 2>&1
kubectl delete role pod-manager -n staging --ignore-not-found >/dev/null 2>&1
kubectl delete rolebinding pod-manager-binding -n staging --ignore-not-found >/dev/null 2>&1

echo "Setup completed for CKS-003 Question 8 (namespace 'staging')"
exit 0
