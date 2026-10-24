#!/bin/bash
# Validate automatic Istio sidecar injection is enabled for the namespace

NAMESPACE="${Q6_NAMESPACE:-payments}"

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "❌ Namespace '$NAMESPACE' not found"
  exit 1
fi

INJECTION=$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.metadata.labels.istio-injection}')
REVISION=$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.metadata.labels.istio\.io/rev}')

# istio-injection=disabled wins over a revision label
if [ "$INJECTION" = "enabled" ] || { [ -n "$REVISION" ] && [ "$INJECTION" != "disabled" ]; }; then
  echo "✅ Namespace '$NAMESPACE' has automatic Istio sidecar injection enabled"
  exit 0
fi

echo "❌ Namespace '$NAMESPACE' does not have automatic injection enabled (istio-injection='$INJECTION', istio.io/rev='$REVISION')"
exit 1
