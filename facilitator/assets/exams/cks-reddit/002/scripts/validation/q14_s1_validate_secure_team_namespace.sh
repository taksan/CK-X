#!/bin/bash
# Validate secure-team namespace enforces restricted Pod Security profile

NAMESPACE="secure-team"

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "❌ Namespace '$NAMESPACE' not found"
  exit 1
fi

LABELS=$(kubectl get namespace "$NAMESPACE" --show-labels 2>/dev/null || true)

if ! echo "$LABELS" | grep -q "pod-security.kubernetes.io/enforce=restricted"; then
  echo "❌ Namespace '$NAMESPACE' does not enforce Pod Security restricted profile via labels"
  exit 1
fi

echo "✅ Namespace '$NAMESPACE' enforces restricted Pod Security profile"
exit 0
