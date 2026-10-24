#!/bin/bash
# Item: ci-bot can still read (get/list/watch) rolebindings in ci-cd and clusterrolebindings.
# Credited only when the escalation is closed.

source "$(dirname "$0")/../lib/rbac-q4.sh"
escalation_closed || { echo "❌ The escalation is still possible (see the two items about cluster-admin and admin): nothing to credit yet"; exit 1; }

for verb in get list watch; do
  [ "$(can_i "$verb" rolebindings.rbac.authorization.k8s.io -n "$Q4_NS")" = "yes" ] || { echo "❌ ci-bot lost '$verb rolebindings' in $Q4_NS"; exit 1; }
  [ "$(can_i "$verb" clusterrolebindings.rbac.authorization.k8s.io)" = "yes" ] || { echo "❌ ci-bot lost '$verb clusterrolebindings'"; exit 1; }
done

echo "✅ ci-bot can still read rolebindings and clusterrolebindings"
exit 0
