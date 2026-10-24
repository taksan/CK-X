#!/bin/bash

# Setup for MHagou CKS exam 9, Question 9: a new user and namespace-scoped permissions.
# Namespace john is exclusive. The candidate saves the signed certificate to /tmp/exam/mhagou-009-q9/john.crt.

source "$(dirname "$0")/../lib/wait-cluster.sh"

DIR="/tmp/exam/mhagou-009-q9"
ensure_namespace john
mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*

echo "Setup completed for MHagou exam 9 Question 9 (namespace 'john', certificate path $DIR/john.crt)"
exit 0
