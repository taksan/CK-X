#!/bin/bash

# Session cleanup for CKS-001, run on the jumphost at exam termination by cleanup-exam-env: the encryption question
# leaves Secrets encrypted in etcd, which the cluster cannot read once the candidate's key is gone.

"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/delete-encrypted-secrets.sh"
exit 0
