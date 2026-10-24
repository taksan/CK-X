#!/bin/bash
# Validate by behaviour: batch-sa and ops-sa cannot read secrets anymore but keep reading
# configmaps; reader-sa (the intended reader) is untouched.
# It also warns when a built-in ClusterRole (edit, view, admin) was modified: those roles are shared by
# every namespace and the API server reconciles them back at each restart, so the access must be
# removed with the RoleBinding of the ServiceAccount, never by editing the built-in role.

NS="rbac-audit"
can() { kubectl auth can-i "$1" "$2" --as="system:serviceaccount:$NS:$3" -n "$NS" 2>/dev/null; }

# the exam start: the setup recreates reader-bind, which the task does not touch
START=$(kubectl get rolebinding reader-bind -n "$NS" -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null)
WARN=""
if [ -n "$START" ]; then
  # a kubectl manager that wrote the role during the exam, or the API server that restored it
  # (it only writes a built-in role when it differs from the default)
  CHANGED=$(kubectl get clusterrole edit view admin -o json --show-managed-fields 2>/dev/null | jq -r --arg s "$START" '
    [.items[] | . as $r | ($r.metadata.managedFields // [])[]
     | select(.time >= $s and ((.manager | startswith("kubectl")) or (.manager == "kube-apiserver")))
     | $r.metadata.name] | unique | join(", ")')
  [ -n "$CHANGED" ] && WARN="⚠️ The built-in ClusterRole(s) $CHANGED were modified during the exam (or restored by the API server). That is the wrong approach: built-in roles are shared by every namespace and the API server reconciles them back when it restarts. Remove the access with the RoleBinding of the ServiceAccount (ops-bind) instead."
fi
finish() { echo "$1"; [ -n "$WARN" ] && echo "$WARN"; exit "$2"; }

for sa in batch-sa ops-sa; do
  for verb in get list watch; do
    [ "$(can $verb secrets $sa)" = "no" ] || finish "❌ $sa can still $verb secrets" 1
  done
  [ "$(can get configmaps $sa)" = "yes" ] || finish "❌ $sa lost its access to configmaps: only the access to secrets had to go" 1
done

[ "$(can get secrets reader-sa)" = "yes" ] || finish "❌ reader-sa lost its access to secrets: it is the intended reader and was not part of the task" 1

finish "✅ batch-sa and ops-sa cannot read secrets anymore; they still read configmaps; reader-sa is untouched" 0
