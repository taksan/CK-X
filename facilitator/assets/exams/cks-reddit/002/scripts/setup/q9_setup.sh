#!/bin/bash

# Setup for CKS-002 Question 9: Kubernetes audit logging with custom policy and rotation
#
# The API server starts without audit flags (reset_apiserver_audit removes them when the cluster has some). The candidate writes the audit policy
# and edits the kube-apiserver manifest; both are put back by the node checkpoint
# restore. The validators read the policy the API server is configured with and evaluate
# it rule by rule (first match wins), so no objects are needed in the cluster.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/audit-reset.sh"

reset_apiserver_audit || exit 1

echo "Setup completed for CKS-002 Question 9"
exit 0
