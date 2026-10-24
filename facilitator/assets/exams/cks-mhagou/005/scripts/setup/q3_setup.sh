#!/bin/bash

# Setup for MHagou-005 Question 3: Pod Security Standards and RBAC. Namespace api-security is
# exclusive. It is created without Pod Security labels; the candidate does everything else.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="api-security"
ensure_namespace "$NS"
for l in enforce audit warn; do
  kubectl label namespace "$NS" "pod-security.kubernetes.io/$l-" >/dev/null 2>&1 || true
done
kubectl delete pods,deployments --all -n "$NS" --force --grace-period=0 >/dev/null 2>&1
kubectl delete rolebinding,role -n "$NS" --all >/dev/null 2>&1
kubectl delete serviceaccount pss-viewer -n "$NS" --ignore-not-found >/dev/null 2>&1

echo "Setup completed for MHagou-005 Question 3 (namespace '$NS')"
exit 0
