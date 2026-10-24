#!/bin/bash

# Setup for MHagou-006 Question 16: a RuntimeClass and a Pod in the gVisor sandbox. Namespace gvisor-lab
# is exclusive and empty. The candidate creates the RuntimeClass: the question must not rely on one that
# happens to exist in the cluster.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace gvisor-lab
kubectl delete runtimeclass hardened --ignore-not-found >/dev/null 2>&1
kubectl delete pod secure -n gvisor-lab --ignore-not-found --now >/dev/null 2>&1

echo "Setup completed for MHagou-006 Question 16 (namespace gvisor-lab)"
exit 0
