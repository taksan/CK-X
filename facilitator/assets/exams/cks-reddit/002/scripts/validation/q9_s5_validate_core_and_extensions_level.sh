#!/bin/bash
# Item 3: the other core and extensions resources are logged at Request

source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

FAIL=0
for verb in create update delete; do
  check_audit_level "Core resources (ConfigMap)" Request "" configmaps "" audit "$verb" || FAIL=1
  check_audit_level "Core resources (Pod)" Request "" pods "" audit "$verb" || FAIL=1
  check_audit_level "Core resources (Secret)" Request "" secrets "" audit "$verb" || FAIL=1
  check_audit_level "Extensions resources (Ingress)" Request extensions ingresses "" audit "$verb" || FAIL=1
done
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ Core and extensions resources are logged at Request"
exit 0
