#!/bin/bash
# Behaviour: with the context of that user the API server authenticates the request as 60099@internal.users

source "$(dirname "$0")/../lib/certuser-q9.sh"
find_user_context && [ -n "$Q9_CTX" ] || { echo "❌ No context of the kubeconfig uses a client certificate for 60099@internal.users"; exit 1; }

WHO=$(kubectl --context "$Q9_CTX" auth whoami -o jsonpath='{.status.userInfo.username}' 2>/dev/null)
[ "$WHO" = "60099@internal.users" ] || { echo "❌ The context '$Q9_CTX' authenticates as '${WHO:-nobody}', expected 60099@internal.users"; exit 1; }

echo "✅ The context '$Q9_CTX' authenticates as 60099@internal.users"
exit 0
