#!/bin/bash

# Setup for CKS-003 Question 9: a new user and namespace-scoped permissions.
# Namespace john is exclusive to this question.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace john

echo "Setup completed for CKS-003 Question 9 (namespace 'john')"
exit 0
