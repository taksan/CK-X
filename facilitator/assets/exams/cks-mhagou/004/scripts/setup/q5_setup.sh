#!/bin/bash

# Setup for MHagou-004 Question 5: an audit policy file for Secrets. Files only (jumphost), no
# namespace: the candidate completes the supplied policy file and does not touch the API server.

source "$(dirname "$0")/../lib/wait-cluster.sh"

DIR="/tmp/exam/mhagou-004-q5"
mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*

cat > "$DIR/audit-policy.yaml" <<'POLICY'
apiVersion: audit.k8s.io/v1
kind: Policy
rules: []
POLICY

echo "Setup completed for MHagou-004 Question 5 (policy file $DIR/audit-policy.yaml)"
exit 0
