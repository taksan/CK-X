#!/bin/bash
# Item 1: reading Secrets (get, list, watch) is logged at Metadata in the policy file

export AUDIT_POLICY_LOCAL_FILE="${Q5_POLICY:-/tmp/exam/mhagou-004-q5/audit-policy.yaml}"
source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

FAIL=0
for verb in get list watch; do
  check_audit_level "Reading Secrets" Metadata "" secrets "" team-a "$verb" || FAIL=1
done
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ get, list and watch of Secrets are logged at Metadata"
exit 0
