#!/bin/bash
# Behaviour: app-reader can get, list and watch Pods, Services and Deployments in rbac-minimize

NS="rbac-minimize"
WHO="system:serviceaccount:$NS:app-reader"

kubectl get serviceaccount app-reader -n "$NS" >/dev/null 2>&1 || { echo "❌ ServiceAccount 'app-reader' not found in namespace '$NS'"; exit 1; }

FAIL=0
for resource in pods services deployments.apps; do
  for verb in get list watch; do
    if [ "$(kubectl auth can-i "$verb" "$resource" -n "$NS" --as="$WHO" 2>/dev/null)" != "yes" ]; then
      echo "❌ app-reader cannot $verb $resource in $NS"
      FAIL=1
    fi
  done
done
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ app-reader can get, list and watch Pods, Services and Deployments in $NS"
exit 0
