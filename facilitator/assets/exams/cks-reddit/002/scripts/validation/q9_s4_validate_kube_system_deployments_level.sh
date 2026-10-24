#!/bin/bash
# Item 2: Deployment changes in kube-system are logged at Request

source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

FAIL=0
for verb in create update patch delete; do
  check_audit_level "Deployment changes in kube-system" Request apps deployments "" kube-system "$verb" || FAIL=1
done
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ Deployment changes in kube-system are logged at Request"
exit 0
