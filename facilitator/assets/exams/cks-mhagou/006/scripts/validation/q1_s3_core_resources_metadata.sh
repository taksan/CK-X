#!/bin/bash
# Requirement: requests on pods, services, configmaps and secrets are logged at Metadata level

source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

FAIL=0
for res in pods services configmaps secrets; do
  for verb in get list create update patch delete; do
    check_audit_level "Core resource $res" Metadata "" "$res" "" kernel-lab "$verb" || FAIL=1
  done
done
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ pods, services, configmaps and secrets are logged at Metadata level"
exit 0
