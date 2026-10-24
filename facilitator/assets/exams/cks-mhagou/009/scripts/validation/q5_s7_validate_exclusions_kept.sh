#!/bin/bash
# Item: the "do not log" rules of the base policy still work (credited once the policy was extended)

source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

[ "$(audit_level "" nodes "" "" patch)" = "RequestResponse" ] || { echo "❌ The base policy was not extended yet (node changes are not logged at RequestResponse): nothing to credit"; exit 1; }

for u in /healthz /readyz/ping /livez /version; do
  L=$(audit_level_url "$u" get)
  [ "$L" = "None" ] || { echo "❌ GET $u is logged at level $L: the base exclusion for health checks and /version is no longer effective (extend the base policy, keep its rules before the catch-all)"; exit 1; }
done

for res in endpoints services; do
  L=$(AUDIT_USER=system:kube-proxy audit_level "" "$res" "" kube-system watch)
  [ "$L" = "None" ] || { echo "❌ The kube-proxy watch of $res is logged at level $L: the base exclusion is no longer effective"; exit 1; }
done

echo "✅ The exclusions of the base policy are still effective"
exit 0
