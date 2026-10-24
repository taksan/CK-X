#!/bin/bash

POLICY_NAME="deny-all"
NAMESPACE="testing"

kubectl get networkpolicy "$POLICY_NAME" -n "$NAMESPACE" >/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "NetworkPolicy '$POLICY_NAME' exists in namespace '$NAMESPACE'"
  exit 0
else
  echo "NetworkPolicy '$POLICY_NAME' not found in namespace '$NAMESPACE'"
  exit 1
fi
