#!/bin/bash
# Item 4: watch requests of system:kube-proxy on endpoints and services are not logged (level None),
# while the same requests of other users are still logged (the rule must be specific)

source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

FAIL=0
AUDIT_USER="system:kube-proxy"
for res in endpoints services; do
  check_audit_level "kube-proxy watches of $res" None "" "$res" "" "" watch || FAIL=1
done
AUDIT_USER="kubernetes-admin"
for res in endpoints services; do
  if [ "$(audit_level "" "$res" "" "" watch)" = "None" ]; then
    echo "❌ watch requests of $res by $AUDIT_USER are not logged either: the rule must be limited to system:kube-proxy"
    FAIL=1
  fi
done
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ The watches of system:kube-proxy on endpoints and services are not logged; other users still are"
exit 0
