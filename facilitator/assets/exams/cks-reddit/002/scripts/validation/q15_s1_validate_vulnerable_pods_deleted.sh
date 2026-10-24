#!/bin/bash
# Validate Pods with CRITICAL vulnerabilities were deleted and the clean Pod was kept

NAMESPACE="supply-chain"

for POD in legacy-web old-httpd; do
  if kubectl get pod "$POD" -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "❌ Pod '$POD' still exists but its image has CRITICAL vulnerabilities"
    exit 1
  fi
done

if ! kubectl get pod tools -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "❌ Pod 'tools' was deleted but its image has no CRITICAL vulnerabilities"
  exit 1
fi

echo "✅ Vulnerable Pods were deleted and Pod 'tools' was kept"
exit 0
