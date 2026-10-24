#!/bin/bash

# Setup for CKS-002 Question 13: ValidatingAdmissionPolicy for trusted registries

source "$(dirname "$0")/../lib/wait-cluster.sh"

NAMESPACE="secure-apps"

ensure_namespace "$NAMESPACE"
# a namespace outside the policy scope, used by the validator to check the scoping
ensure_namespace open-apps

# Start without any policy
kubectl delete validatingadmissionpolicybinding trusted-registries-binding --ignore-not-found >/dev/null 2>&1 || true
kubectl delete validatingadmissionpolicy trusted-registries --ignore-not-found >/dev/null 2>&1 || true

echo "Setup completed for CKS-002 Question 13 (namespace '$NAMESPACE' ready)"
exit 0
