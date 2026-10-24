#!/bin/bash
# Validate the ServiceAccount itself disables the automatic token mount

J=$(kubectl get serviceaccount hidden-user -n secret-room -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ ServiceAccount 'hidden-user' not found in namespace 'secret-room'"; exit 1; }

V=$(echo "$J" | jq -r '.automountServiceAccountToken')
[ "$V" = "false" ] || { echo "❌ automountServiceAccountToken of 'hidden-user' is '$V', expected false (set it on the ServiceAccount, not only on the Pod)"; exit 1; }

echo "✅ 'hidden-user' has automountServiceAccountToken: false"
exit 0
