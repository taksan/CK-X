#!/bin/bash
# Validate the ValidatingAdmissionPolicyBinding trusted-registries-binding (policy + Deny).
# The scoping to the secure-apps namespace is checked by behaviour in q13_s3, whatever way it is written.

BINDING="trusted-registries-binding"

JSON=$(kubectl get validatingadmissionpolicybinding "$BINDING" -o json 2>/dev/null || true)
if [ -z "$JSON" ]; then
  echo "❌ ValidatingAdmissionPolicyBinding '$BINDING' not found"
  exit 1
fi

if [ "$(echo "$JSON" | jq -r '.spec.policyName')" != "trusted-registries" ]; then
  echo "❌ Binding '$BINDING' does not reference policy 'trusted-registries'"
  exit 1
fi

if ! echo "$JSON" | jq -e '.spec.validationActions | index("Deny")' >/dev/null; then
  echo "❌ Binding '$BINDING' does not use the Deny validation action"
  exit 1
fi

echo "✅ Binding '$BINDING' enforces the policy with the Deny action"
exit 0
