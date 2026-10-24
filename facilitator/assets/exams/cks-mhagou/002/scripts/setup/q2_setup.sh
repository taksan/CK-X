#!/bin/bash

# Setup for MHAGOU-002 Question 2: ServiceAccount, Role and RoleBinding in the namespace seminar
# (exclusive to this question). Nothing is created: the candidate builds all three objects.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="seminar"
ensure_namespace "$NS"

kubectl delete rolebinding k8s-seminar-bind -n "$NS" --ignore-not-found >/dev/null 2>&1
kubectl delete role k8s-seminar -n "$NS" --ignore-not-found >/dev/null 2>&1
kubectl delete serviceaccount seminar-sa -n "$NS" --ignore-not-found >/dev/null 2>&1

echo "Setup completed for MHAGOU-002 Question 2 (namespace '$NS')"
exit 0
