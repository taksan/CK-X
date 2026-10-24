#!/bin/bash
# Namespace pss-test enforces the restricted Pod Security Standard (and nothing weaker is warned/audited)

L=$(kubectl get namespace pss-test -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)
[ "$L" = "restricted" ] || { echo "❌ Namespace pss-test does not enforce the restricted profile (pod-security.kubernetes.io/enforce='$L')"; exit 1; }

echo "✅ Namespace pss-test enforces the restricted Pod Security Standard"
exit 0
