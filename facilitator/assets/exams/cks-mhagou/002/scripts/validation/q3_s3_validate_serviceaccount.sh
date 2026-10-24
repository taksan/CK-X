#!/bin/bash
# The ServiceAccount test-sa exists in apparmor-lab and apparmor-pod uses it

NS="apparmor-lab"
[ -n "$(kubectl get serviceaccount test-sa -n "$NS" -o name 2>/dev/null)" ] || { echo "❌ ServiceAccount 'test-sa' not found in namespace '$NS'"; exit 1; }
SA=$(kubectl get pod apparmor-pod -n "$NS" -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
if [ "$SA" != "test-sa" ]; then
  echo "❌ The Pod apparmor-pod uses the ServiceAccount '${SA:-<none>}', expected test-sa"
  exit 1
fi
echo "✅ apparmor-pod uses the ServiceAccount test-sa"
exit 0
