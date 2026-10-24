#!/bin/bash
# Item: changes to nodes are logged at RequestResponse

source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

FAIL=0
for verb in create update patch delete; do
  check_audit_level "Node changes" RequestResponse "" nodes "" "" "$verb" || FAIL=1
done
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ Node changes are logged at RequestResponse"
exit 0
