#!/bin/bash
# Validate that the secure pod exists and complies with Pod Security Standards

POD_NAME="secure-pod"
NAMESPACE="api-security"

# Check if pod exists
kubectl get pod $POD_NAME -n $NAMESPACE &> /dev/null
if [ $? -ne 0 ]; then
  echo "❌ Pod '$POD_NAME' not found in namespace '$NAMESPACE'"
  exit 1
fi

# Check if pod is running
POD_STATUS=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.phase}')
if [ "$POD_STATUS" != "Running" ]; then
  echo "❌ Pod '$POD_NAME' is not in Running state (current state: $POD_STATUS)"
  exit 1
fi

OUT=$(kubectl label --dry-run=server --overwrite ns "$NAMESPACE" \
      pod-security.kubernetes.io/enforce=baseline 2>&1)
if echo "$OUT" | grep -q "$POD_NAME"; then
  echo "❌ Pod '$POD_NAME' violates the 'baseline' Pod Security Standard:"
  echo "$OUT" | grep -A5 "$POD_NAME"
  exit 1
fi

echo "✅ Pod exists and complies with Pod Security Standards"
exit 0 
