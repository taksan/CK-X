#!/bin/bash
# ValidatingAdmissionPolicy pod-psp and a binding pod-psp-binding that denies (not only warns)

kubectl get validatingadmissionpolicy pod-psp >/dev/null 2>&1 || { echo "❌ ValidatingAdmissionPolicy 'pod-psp' not found"; exit 1; }
B=$(kubectl get validatingadmissionpolicybinding pod-psp-binding -o json 2>/dev/null)
[ -n "$B" ] || { echo "❌ ValidatingAdmissionPolicyBinding 'pod-psp-binding' not found"; exit 1; }
[ "$(echo "$B" | jq -r '.spec.policyName')" = "pod-psp" ] || { echo "❌ The binding does not reference the policy pod-psp"; exit 1; }
echo "$B" | jq -e '.spec.validationActions | index("Deny")' >/dev/null || { echo "❌ The binding must use the Deny validation action"; exit 1; }

echo "✅ Policy pod-psp and binding pod-psp-binding exist (Deny)"
exit 0
