#!/bin/bash
# Behaviour: app-reader has read access only on those three resources and nothing more
# (credited only when the read access exists, otherwise this check would pass before any work is done)

NS="rbac-minimize"
WHO="system:serviceaccount:$NS:app-reader"
can() { kubectl auth can-i "$@" --as="$WHO" 2>/dev/null; }

for resource in pods services deployments.apps; do
  [ "$(can list "$resource" -n "$NS")" = "yes" ] || { echo "❌ The read access to $resource is missing: nothing to credit yet"; exit 1; }
done

FAIL=0
for resource in pods services deployments.apps; do
  for verb in create update patch delete deletecollection; do
    [ "$(can "$verb" "$resource" -n "$NS")" = "no" ] || { echo "❌ app-reader can $verb $resource: read-only access was requested"; FAIL=1; }
  done
done
for resource in secrets configmaps statefulsets.apps daemonsets.apps jobs.batch serviceaccounts; do
  [ "$(can get "$resource" -n "$NS")" = "no" ] || { echo "❌ app-reader can read $resource: only Pods, Services and Deployments were requested"; FAIL=1; }
done
[ "$(can list pods -n kube-system)" = "no" ] || { echo "❌ app-reader can list Pods in other namespaces: the access must be limited to $NS"; FAIL=1; }
[ "$(can list nodes)" = "no" ] || { echo "❌ app-reader can list nodes"; FAIL=1; }
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ app-reader has no permission beyond read access to Pods, Services and Deployments in $NS"
exit 0
