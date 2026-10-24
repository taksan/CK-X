#!/bin/bash
# Item: policy deny-latest-tag and binding deny-latest-tag-binding exist, the binding denies

kubectl get validatingadmissionpolicy deny-latest-tag >/dev/null 2>&1 || { echo "❌ ValidatingAdmissionPolicy deny-latest-tag not found"; exit 1; }
B=$(kubectl get validatingadmissionpolicybinding deny-latest-tag-binding -o json 2>/dev/null)
[ -n "$B" ] || { echo "❌ ValidatingAdmissionPolicyBinding deny-latest-tag-binding not found"; exit 1; }
[ "$(echo "$B" | jq -r '.spec.policyName')" = "deny-latest-tag" ] || { echo "❌ The binding does not reference deny-latest-tag"; exit 1; }
echo "$B" | jq -e '(.spec.validationActions // []) | index("Deny") != null' >/dev/null || { echo "❌ The binding must use the Deny validation action"; exit 1; }

echo "✅ Policy and binding exist (Deny)"
exit 0
