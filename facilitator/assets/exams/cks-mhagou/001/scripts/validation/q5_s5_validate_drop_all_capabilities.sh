#!/bin/bash
# Item: every container of the Deployment drops ALL Linux capabilities

F="${Q5_DEPLOYMENT:-/tmp/exam/mhagou-001-q5/deployment.yaml}"
[ -f "$F" ] || { echo "❌ $F does not exist"; exit 1; }

J=$(kubectl create --dry-run=client -o json -f "$F" 2>/dev/null)
[ -n "$J" ] || { echo "❌ $F is not a valid Kubernetes manifest"; exit 1; }

if ! echo "$J" | jq -e '(.spec.template.spec.containers | length) >= 1 and all(.spec.template.spec.containers[]; ((.securityContext.capabilities.drop // []) | map(ascii_upcase) | index("ALL")) != null)' >/dev/null; then
  echo "❌ Not every container drops ALL capabilities (capabilities.drop must contain ALL)"
  exit 1
fi

echo "✅ All containers drop ALL capabilities"
exit 0
