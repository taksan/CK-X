#!/bin/bash
# Item: the ValidatingAdmissionPolicy require-env-label for namespaces and its binding (Deny) exist

P=$(kubectl get validatingadmissionpolicy require-env-label -o json 2>/dev/null)
[ -n "$P" ] || { echo "❌ ValidatingAdmissionPolicy 'require-env-label' not found"; exit 1; }
echo "$P" | jq -e '[.spec.matchConstraints.resourceRules[]? | select((.resources // []) | any(. == "namespaces" or . == "*"))] | length > 0' >/dev/null \
  || { echo "❌ The policy does not match the resource namespaces"; exit 1; }

B=$(kubectl get validatingadmissionpolicybinding require-env-label-binding -o json 2>/dev/null)
[ -n "$B" ] || { echo "❌ ValidatingAdmissionPolicyBinding 'require-env-label-binding' not found"; exit 1; }
[ "$(echo "$B" | jq -r '.spec.policyName')" = "require-env-label" ] || { echo "❌ The binding does not reference require-env-label"; exit 1; }
echo "$B" | jq -e '(.spec.validationActions // []) | index("Deny") != null' >/dev/null || { echo "❌ The binding must use the Deny validation action"; exit 1; }

echo "✅ require-env-label and require-env-label-binding exist (Deny)"
exit 0
