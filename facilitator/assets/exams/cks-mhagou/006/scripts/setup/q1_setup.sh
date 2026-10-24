#!/bin/bash

# Setup for MHagou-006 Question 1: API server auditing on the control plane.
# The API server starts without audit flags (reset_apiserver_audit removes them when the cluster has some); the candidate creates the policy under
# /etc/kubernetes/audit, edits the kube-apiserver manifest and waits for the restart. Both are put
# back by the node checkpoint restore (etc/kubernetes is tracked and cleaned).

source "$(dirname "$0")/../lib/nodes.sh"

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/audit-reset.sh"

reset_apiserver_audit || exit 1
echo "Setup completed for MHagou-006 Question 1 (control plane ${CONTROL_PLANE})"
exit 0
