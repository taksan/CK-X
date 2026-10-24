#!/bin/bash
# Item: the request body of PersistentVolumeClaim changes in the namespace frontend is logged
# (level Request, or RequestResponse which includes it)

source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

for verb in create update patch delete; do
  L=$(audit_level "" persistentvolumeclaims "" frontend "$verb")
  case "$L" in
    Request|RequestResponse) ;;
    *) echo "❌ $verb persistentvolumeclaims in namespace frontend is logged at level $L (rule #$(audit_rule_index "" persistentvolumeclaims "" frontend "$verb")), expected Request"; exit 1 ;;
  esac
done

echo "✅ PersistentVolumeClaim changes in frontend are logged with their request body"
exit 0
