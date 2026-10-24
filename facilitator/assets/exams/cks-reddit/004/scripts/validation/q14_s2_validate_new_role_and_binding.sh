#!/bin/bash
# Validate Role web-sts-updater (only update on statefulsets) bound to web-sa; the decoy is untouched

NS="database"
SA="system:serviceaccount:$NS:web-sa"
can() { kubectl auth can-i "$@" --as="$SA" -n "$NS" 2>/dev/null; }

R=$(kubectl get role web-sts-updater -n "$NS" -o json 2>/dev/null)
[ -n "$R" ] || { echo "❌ Role 'web-sts-updater' not found in namespace '$NS'"; exit 1; }
echo "$R" | jq -e '(.rules | length >= 1) and all(.rules[]; (.verbs == ["update"]) and (.resources == ["statefulsets"]) and ((.apiGroups // []) | index("apps") != null))' >/dev/null \
  || { echo "❌ Role 'web-sts-updater' must allow only update on statefulsets (apps)"; exit 1; }

B=$(kubectl get rolebinding web-sts-updater-bind -n "$NS" -o json 2>/dev/null)
[ -n "$B" ] || { echo "❌ RoleBinding 'web-sts-updater-bind' not found"; exit 1; }
echo "$B" | jq -e '.roleRef.name == "web-sts-updater" and .roleRef.kind == "Role" and any(.subjects[]?; .kind == "ServiceAccount" and .name == "web-sa" and (.namespace // "database") == "database")' >/dev/null \
  || { echo "❌ RoleBinding 'web-sts-updater-bind' must bind Role web-sts-updater to ServiceAccount web-sa"; exit 1; }

[ "$(can update statefulsets.apps)" = "yes" ] || { echo "❌ web-sa cannot update statefulsets"; exit 1; }
for v in get delete create patch; do
  [ "$(can $v statefulsets.apps)" = "no" ] || { echo "❌ web-sa can also $v statefulsets"; exit 1; }
done

# the decoy must be untouched
[ "$(kubectl auth can-i list pods --as=system:serviceaccount:$NS:audit-sa -n $NS 2>/dev/null)" = "yes" ] \
  && [ "$(kubectl auth can-i list events --as=system:serviceaccount:$NS:audit-sa -n $NS 2>/dev/null)" = "yes" ] \
  || { echo "❌ The permissions of audit-sa were changed: it was not part of the task"; exit 1; }

echo "✅ web-sts-updater and its binding are correct"
exit 0
