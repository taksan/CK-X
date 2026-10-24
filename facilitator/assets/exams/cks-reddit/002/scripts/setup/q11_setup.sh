#!/bin/bash

# Setup for CKS-002 Question 11: Encryption at rest for Secrets
#
# The API server starts without an encryption configuration. The candidate creates
# the configuration and edits the kube-apiserver manifest; both are put back by the
# node checkpoint restore. The namespace "encryption" is used only by the validator,
# which creates a throwaway Secret there and reads it from etcd.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace encryption

echo "Setup completed for CKS-002 Question 11"
exit 0
