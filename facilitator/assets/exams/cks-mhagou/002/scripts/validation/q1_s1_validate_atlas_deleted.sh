#!/bin/bash
# The Pod atlas runs nginx:1.16 (CRITICAL vulnerabilities): it must be deleted

NS="spectacle"
STATE=$(kubectl get pod atlas -n "$NS" -o json 2>/dev/null | jq -r 'select(.metadata.deletionTimestamp == null) | .metadata.name')
if [ -n "$STATE" ]; then
  echo "❌ The Pod 'atlas' (nginx:1.16, CRITICAL vulnerabilities) still exists"
  exit 1
fi
echo "✅ The Pod running the CRITICAL image nginx:1.16 was deleted"
exit 0
