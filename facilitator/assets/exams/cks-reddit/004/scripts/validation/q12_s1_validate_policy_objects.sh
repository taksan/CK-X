#!/bin/bash
# Validate the policy and the binding exist and the binding denies (no only warn / audit)

kubectl get validatingadmissionpolicy prevent-volume-policy >/dev/null 2>&1 || { echo "❌ ValidatingAdmissionPolicy 'prevent-volume-policy' not found"; exit 1; }
B=$(kubectl get validatingadmissionpolicybinding prevent-volume-binding -o json 2>/dev/null)
[ -n "$B" ] || { echo "❌ ValidatingAdmissionPolicyBinding 'prevent-volume-binding' not found"; exit 1; }

[ "$(echo "$B" | jq -r '.spec.policyName')" = "prevent-volume-policy" ] || { echo "❌ The binding does not reference prevent-volume-policy"; exit 1; }
echo "$B" | jq -e '.spec.validationActions | index("Deny")' >/dev/null || { echo "❌ The binding must use the Deny validation action"; exit 1; }

echo "✅ Policy and binding exist (Deny)"
exit 0
