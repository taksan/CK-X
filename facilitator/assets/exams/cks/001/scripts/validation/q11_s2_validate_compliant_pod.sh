#!/bin/bash
# Validate that compliant pod exists

POD_NAME="compliant-pod"
NAMESPACE="pod-security"

# Check if namespace exists
kubectl get namespace $NAMESPACE &> /dev/null
if [ $? -ne 0 ]; then
  echo "❌ Namespace '$NAMESPACE' not found"
  exit 1
fi

# Check if pod exists
kubectl get pod $POD_NAME -n $NAMESPACE &> /dev/null
if [ $? -ne 0 ]; then
  echo "❌ Pod '$POD_NAME' not found in namespace '$NAMESPACE'"
  exit 1
fi

# Check if pod is running (which means it complies with PSS)
POD_STATUS=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.phase}')
if [ "$POD_STATUS" != "Running" ]; then
  echo "❌ Pod is not in Running state. Current state: $POD_STATUS"
  exit 1
fi

# Verify basic PSS baseline compliance
OUT=$(kubectl label --dry-run=server --overwrite ns "$NAMESPACE" \
      pod-security.kubernetes.io/enforce=baseline 2>&1)
if echo "$OUT" | grep -q "$POD_NAME"; then
  echo "❌ Pod '$POD_NAME' violates the 'baseline' Pod Security Standard:"
  echo "$OUT" | grep -A5 "$POD_NAME"
  exit 1
fi


echo "✅ Compliant pod exists"
exit 0 
