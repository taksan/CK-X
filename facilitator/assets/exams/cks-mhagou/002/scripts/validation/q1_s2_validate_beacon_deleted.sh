#!/bin/bash
# The Pod beacon runs httpd:2.4.49 (CRITICAL vulnerabilities): it must be deleted

NS="spectacle"
STATE=$(kubectl get pod beacon -n "$NS" -o json 2>/dev/null | jq -r 'select(.metadata.deletionTimestamp == null) | .metadata.name')
if [ -n "$STATE" ]; then
  echo "❌ The Pod 'beacon' (httpd:2.4.49, CRITICAL vulnerabilities) still exists"
  exit 1
fi
echo "✅ The Pod running the CRITICAL image httpd:2.4.49 was deleted"
exit 0
