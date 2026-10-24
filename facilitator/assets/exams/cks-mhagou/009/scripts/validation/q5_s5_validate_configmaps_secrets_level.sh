#!/bin/bash
# Item: ConfigMap and Secret changes in all namespaces are logged at Metadata

source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

FAIL=0
for ns in frontend kube-system default; do
  for res in configmaps secrets; do
    for verb in create update patch delete; do
      check_audit_level "ConfigMap/Secret changes" Metadata "" "$res" "" "$ns" "$verb" || FAIL=1
    done
  done
done
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ ConfigMap and Secret changes are logged at Metadata in every namespace"
exit 0
