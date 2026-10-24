#!/bin/bash
# Behaviour: as that user, listing the Pods of the namespace staff-lab is rejected by authorization
# (Forbidden) and no RBAC rule grants it

source "$(dirname "$0")/../lib/certuser-q9.sh"
find_user_context && [ -n "$Q9_CTX" ] || { echo "❌ No context of the kubeconfig uses a client certificate for 60099@internal.users"; exit 1; }

WHO=$(kubectl --context "$Q9_CTX" auth whoami -o jsonpath='{.status.userInfo.username}' 2>/dev/null)
[ "$WHO" = "60099@internal.users" ] || { echo "❌ The context '$Q9_CTX' does not authenticate as 60099@internal.users"; exit 1; }

OUT=$(kubectl --context "$Q9_CTX" get pods -n staff-lab 2>&1)
echo "$OUT" | grep -qi 'forbidden' || { echo "❌ Listing the Pods of staff-lab as 60099@internal.users is not rejected (got: $(echo "$OUT" | head -1 | cut -c1-120))"; exit 1; }
[ "$(kubectl auth can-i list pods -n staff-lab --as=60099@internal.users 2>/dev/null)" = "no" ] || { echo "❌ An RBAC rule grants 60099@internal.users the right to list Pods in staff-lab"; exit 1; }

echo "✅ 60099@internal.users is authenticated but cannot list the Pods of staff-lab (Forbidden)"
exit 0
