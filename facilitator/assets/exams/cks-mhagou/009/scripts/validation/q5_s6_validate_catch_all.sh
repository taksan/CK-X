#!/bin/bash
# Item: all other requests are logged at Metadata (resources and non-resource URLs)

source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

FAIL=0
check_audit_level "Other requests (Deployment)" Metadata apps deployments "" frontend create || FAIL=1
check_audit_level "Other requests (Role)" Metadata rbac.authorization.k8s.io roles "" frontend update || FAIL=1
check_audit_level "Other requests (Pod)" Metadata "" pods "" frontend delete || FAIL=1
L=$(audit_level_url /apis get)
[ "$L" = "Metadata" ] || { echo "❌ Other requests (GET /apis): logged at level $L, expected Metadata"; FAIL=1; }
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ All other requests are logged at Metadata"
exit 0
