#!/bin/bash
# Deployment kafka (apps/v1): no regular container and no init container is privileged
F="${Q4_DEPLOYMENT:-/tmp/exam/mhagou-006-q4/Deployment.yaml}"
[ -f "$F" ] || { echo "❌ $F does not exist"; exit 1; }
J=$(kubectl create --dry-run=client -o json -f "$F" 2>/dev/null)
[ -n "$J" ] || { echo "❌ $F is not a valid manifest (is the apiVersion of the Deployment apps/v1?)"; exit 1; }
echo "$J" | jq -e '.apiVersion == "apps/v1" and .kind == "Deployment" and .metadata.name == "kafka"' >/dev/null \
  || { echo "❌ The manifest must be the Deployment 'kafka' with apiVersion apps/v1"; exit 1; }

N=$(echo "$J" | jq '[.spec.template.spec.containers[]?, .spec.template.spec.initContainers[]?] | length')
[ "$N" -ge 2 ] || { echo "❌ The containers of the Deployment were removed (kafka and the init container must stay)"; exit 1; }
BAD=$(echo "$J" | jq -r '[.spec.template.spec.containers[]?, .spec.template.spec.initContainers[]? | select(.securityContext.privileged == true) | .name] | join(", ")')
[ -z "$BAD" ] || { echo "❌ Privileged containers: $BAD"; exit 1; }

echo "✅ The Deployment is apps/v1 and no container is privileged"
exit 0
