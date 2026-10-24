#!/bin/bash
# Item 6: all other requests are logged at Metadata

source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

FAIL=0
check_audit_level "Other requests (Deployment)" Metadata apps deployments "" audit-lab create || FAIL=1
check_audit_level "Other requests (Role)" Metadata rbac.authorization.k8s.io roles "" audit-lab create || FAIL=1
check_audit_level "Other requests (Job)" Metadata batch jobs "" audit-lab delete || FAIL=1
check_audit_level "Other requests (CustomResource-like group)" Metadata cilium.io ciliumnetworkpolicies "" audit-lab update || FAIL=1
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ All other requests are logged at Metadata"
exit 0
