#!/bin/bash
# Item 4: pods/portforward and services/proxy are logged at Metadata

source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

FAIL=0
for verb in get create; do
  check_audit_level "pods/portforward" Metadata "" pods portforward audit-lab "$verb" || FAIL=1
done
for verb in get create; do
  check_audit_level "services/proxy" Metadata "" services proxy audit-lab "$verb" || FAIL=1
done
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ pods/portforward and services/proxy are logged at Metadata"
exit 0
