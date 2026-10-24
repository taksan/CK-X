#!/bin/bash
# The policy logs delete and update of pods in the namespace test at the Metadata level

export AUDIT_POLICY_FILE=/etc/kubernetes/test-audit.yaml
source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

FAIL=0
for verb in delete update; do
  check_audit_level "Pod ${verb}s in the namespace test" Metadata "" pods "" test "$verb" || FAIL=1
done
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ Deleting and updating pods in the namespace test is logged at Metadata level"
exit 0
