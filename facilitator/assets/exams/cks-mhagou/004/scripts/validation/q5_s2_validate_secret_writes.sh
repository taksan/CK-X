#!/bin/bash
# Item 2: changing Secrets (create, update, patch, delete, deletecollection) is logged at Metadata

export AUDIT_POLICY_LOCAL_FILE="${Q5_POLICY:-/tmp/exam/mhagou-004-q5/audit-policy.yaml}"
source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

FAIL=0
for verb in create update patch delete deletecollection; do
  check_audit_level "Changing Secrets" Metadata "" secrets "" team-a "$verb" || FAIL=1
done
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ create, update, patch and delete of Secrets are logged at Metadata"
exit 0
