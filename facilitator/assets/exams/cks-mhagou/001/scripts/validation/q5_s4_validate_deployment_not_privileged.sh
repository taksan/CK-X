#!/bin/bash
# Item: the Deployment manifest is valid and its container is not privileged

F="${Q5_DEPLOYMENT:-/tmp/exam/mhagou-001-q5/deployment.yaml}"
[ -f "$F" ] || { echo "❌ $F does not exist"; exit 1; }

J=$(kubectl create --dry-run=client -o json -f "$F" 2>/dev/null)
[ -n "$J" ] || { echo "❌ $F is not a valid Kubernetes manifest"; exit 1; }

echo "$J" | jq -e '.kind == "Deployment" and (.spec.template.spec.containers | length) >= 1' >/dev/null || { echo "❌ $F is not a Deployment with a container"; exit 1; }
if echo "$J" | jq -e 'any(.spec.template.spec.containers[]; .securityContext.privileged == true)' >/dev/null; then
  echo "❌ A container of the Deployment is still privileged"
  exit 1
fi
echo "$J" | jq -e 'any(.spec.template.spec.containers[]; .securityContext != null)' >/dev/null || { echo "❌ The securityContext of the container was removed instead of being hardened"; exit 1; }

echo "✅ The Deployment is valid and not privileged"
exit 0
