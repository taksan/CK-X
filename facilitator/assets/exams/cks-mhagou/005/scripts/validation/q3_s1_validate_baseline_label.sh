#!/bin/bash
# The namespace api-security enforces the baseline Pod Security Standard (label enforce=baseline)

L=$(kubectl get namespace api-security -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)
[ -n "$L" ] || { echo "❌ The namespace api-security has no pod-security.kubernetes.io/enforce label"; exit 1; }
[ "$L" = "baseline" ] || { echo "❌ The namespace enforces '$L': the task asks for the baseline profile"; exit 1; }

echo "✅ api-security enforces the baseline profile"
exit 0
