#!/bin/bash

# Setup for MHAGOU-002 Question 11: Pod restrictions with a ValidatingAdmissionPolicy (the source
# task asked for a PodSecurityPolicy, which no longer exists). Namespaces policy-lab (target) and
# open-lab (must stay unrestricted) are exclusive. The cluster-scoped objects pod-psp and
# pod-psp-binding are deleted here and by the session cleanup.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace policy-lab
ensure_namespace open-lab

kubectl delete validatingadmissionpolicybinding pod-psp-binding --ignore-not-found >/dev/null 2>&1
kubectl delete validatingadmissionpolicy pod-psp --ignore-not-found >/dev/null 2>&1

echo "Setup completed for MHAGOU-002 Question 11 (namespaces policy-lab and open-lab)"
exit 0
