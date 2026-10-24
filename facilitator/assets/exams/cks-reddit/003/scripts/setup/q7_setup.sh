#!/bin/bash

# Setup for CKS-003 Question 7: RuntimeClass untrusted (gVisor). Namespace sandbox is
# exclusive to this question; the dmesg output goes to a file in the working directory.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace sandbox
mkdir -p /tmp/exam/cks-003-q7
rm -f /tmp/exam/cks-003-q7/*

echo "Setup completed for CKS-003 Question 7 (namespace 'sandbox')"
exit 0
