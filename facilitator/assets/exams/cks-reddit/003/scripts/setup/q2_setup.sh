#!/bin/bash

# Setup for CKS-003 Question 2: audit logging with custom policy and rotation
#
# The API server starts without audit flags (reset_apiserver_audit removes them when the cluster has some). The candidate writes the audit policy and
# edits the kube-apiserver manifest; both are put back by the node checkpoint restore.
# The validators read the policy the API server is configured with and evaluate it rule by rule
# (first match wins), so nothing else is needed in the namespace audit-lab.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/audit-reset.sh"

reset_apiserver_audit || exit 1

NAMESPACE="audit-lab"

ensure_namespace "$NAMESPACE"

kubectl delete pod probe-target -n "$NAMESPACE" --ignore-not-found --now >/dev/null 2>&1
kubectl delete svc probe-svc -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1

echo "Setup completed for CKS-003 Question 2 (namespace '$NAMESPACE')"
exit 0
