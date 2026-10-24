#!/bin/bash
# Requirement: the other requests (changes of other resources) are logged at Request level

source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

FAIL=0
for verb in create update patch delete; do
  check_audit_level "Other requests (Deployment)" Request apps deployments "" kernel-lab "$verb" || FAIL=1
  check_audit_level "Other requests (Role)" Request rbac.authorization.k8s.io roles "" kernel-lab "$verb" || FAIL=1
  check_audit_level "Other requests (Namespace)" Request "" namespaces "" "" "$verb" || FAIL=1
  check_audit_level "Other requests (Node)" Request "" nodes "" "" "$verb" || FAIL=1
done
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ Changes of other resources are logged at Request level"
exit 0
