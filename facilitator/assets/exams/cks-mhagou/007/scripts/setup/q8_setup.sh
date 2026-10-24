#!/bin/bash

# Setup for MHAGOU-007 Question 8: an admission policy that requires a label on Namespaces.
# The source used OPA Gatekeeper (not installed here); the same requirement is implemented with a
# ValidatingAdmissionPolicy. It is limited to the namespaces named lab-* so that the rest of the cluster
# (and the other questions) can still create namespaces. Nothing exists at the start.

source "$(dirname "$0")/../lib/wait-cluster.sh"

kubectl delete validatingadmissionpolicybinding require-env-label-binding --ignore-not-found >/dev/null 2>&1
kubectl delete validatingadmissionpolicy require-env-label --ignore-not-found >/dev/null 2>&1

echo "Setup completed for MHAGOU-007 Question 8 (cluster-scoped objects: policy require-env-label)"
exit 0
