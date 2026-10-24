#!/bin/bash
# Validate that Deployment webapp in secure-team complies with restricted profile and is running

NAMESPACE="secure-team"
DEPLOY="webapp"

if ! kubectl get deployment "$DEPLOY" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "❌ Deployment '$DEPLOY' not found in namespace '$NAMESPACE'"
  exit 1
fi

# Check there is at least one ready replica
READY=$(kubectl get deployment "$DEPLOY" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
if [ -z "$READY" ] || [ "$READY" = "0" ]; then
  echo "❌ Deployment '$DEPLOY' has no ready replicas in namespace '$NAMESPACE'"
  exit 1
fi

# Inspect pod template securityContext for common restricted requirements
YAML=$(kubectl get deployment "$DEPLOY" -n "$NAMESPACE" -o yaml 2>/dev/null || true)

if echo "$YAML" | grep -q "privileged: true"; then
  echo "❌ Deployment '$DEPLOY' still uses privileged: true in securityContext"
  exit 1
fi

if echo "$YAML" | grep -q "runAsUser: 0"; then
  echo "❌ Deployment '$DEPLOY' still runs as root (runAsUser: 0)"
  exit 1
fi

if echo "$YAML" | grep -q "hostPath:"; then
  echo "❌ Deployment '$DEPLOY' still uses hostPath volumes"
  exit 1
fi

if echo "$YAML" | grep -q "capabilities:" && echo "$YAML" | grep -q "add:"; then
  echo "❌ Deployment '$DEPLOY' still adds Linux capabilities"
  exit 1
fi

echo "✅ Deployment '$DEPLOY' in '$NAMESPACE' complies with restricted profile and is running"
exit 0
