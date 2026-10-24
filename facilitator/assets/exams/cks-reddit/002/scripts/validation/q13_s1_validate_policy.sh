#!/bin/bash
# Validate the ValidatingAdmissionPolicy trusted-registries

POLICY="trusted-registries"

JSON=$(kubectl get validatingadmissionpolicy "$POLICY" -o json 2>/dev/null || true)
if [ -z "$JSON" ]; then
  echo "❌ ValidatingAdmissionPolicy '$POLICY' not found"
  exit 1
fi

if ! echo "$JSON" | jq -e '[.spec.matchConstraints.resourceRules[]? | select((.resources | index("pods")) and (.operations | (index("CREATE") or index("*"))))] | length > 0' >/dev/null; then
  echo "❌ Policy '$POLICY' does not match Pods on CREATE"
  exit 1
fi

EXPRS=$(echo "$JSON" | jq -r '.spec.validations[]?.expression')
if ! echo "$EXPRS" | grep -q "registry.k8s.io/"; then
  echo "❌ Policy '$POLICY' has no validation expression checking registry.k8s.io/"
  exit 1
fi

echo "✅ ValidatingAdmissionPolicy '$POLICY' validates Pod images against registry.k8s.io/"
exit 0
