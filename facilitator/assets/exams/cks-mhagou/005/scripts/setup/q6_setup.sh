#!/bin/bash

# Setup for MHagou-005 Question 6: least-privilege RBAC. Namespace rbac-minimize is exclusive.
# The ServiceAccount app-reader exists and has no permission.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="rbac-minimize"
ensure_namespace "$NS"
kubectl delete rolebinding,role --all -n "$NS" >/dev/null 2>&1
kubectl delete clusterrolebinding rbac-minimize-app-reader >/dev/null 2>&1
kubectl delete serviceaccount app-reader -n "$NS" --ignore-not-found >/dev/null 2>&1
kubectl create serviceaccount app-reader -n "$NS" >/dev/null

echo "Setup completed for MHagou-005 Question 6 (namespace '$NS')"
exit 0
