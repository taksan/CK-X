#!/bin/bash

# Setup for CKS-004 Question 12: ValidatingAdmissionPolicy limiting volume types.
# Namespaces volume-lab (policy target) and open-volumes (must stay unrestricted) are exclusive.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace volume-lab
ensure_namespace open-volumes

kubectl delete validatingadmissionpolicybinding prevent-volume-binding --ignore-not-found >/dev/null 2>&1
kubectl delete validatingadmissionpolicy prevent-volume-policy --ignore-not-found >/dev/null 2>&1

echo "Setup completed for CKS-004 Question 12 (namespaces volume-lab and open-volumes)"
exit 0
