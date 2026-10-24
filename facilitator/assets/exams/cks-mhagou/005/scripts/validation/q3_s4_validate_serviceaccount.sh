#!/bin/bash
# The ServiceAccount pss-viewer exists in api-security

kubectl get serviceaccount pss-viewer -n api-security >/dev/null 2>&1 || { echo "❌ ServiceAccount 'pss-viewer' not found in namespace 'api-security'"; exit 1; }
echo "✅ ServiceAccount pss-viewer exists"
exit 0
