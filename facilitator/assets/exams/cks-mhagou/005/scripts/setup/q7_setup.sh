#!/bin/bash

# Setup for MHagou-005 Question 7: ServiceAccount without token automounting. Namespace
# service-account-caution is exclusive; the candidate creates the ServiceAccount and the Deployment.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="service-account-caution"
ensure_namespace "$NS"
kubectl delete deployment secure-app -n "$NS" --ignore-not-found >/dev/null 2>&1
kubectl delete serviceaccount minimal-sa -n "$NS" --ignore-not-found >/dev/null 2>&1

echo "Setup completed for MHagou-005 Question 7 (namespace '$NS')"
exit 0
