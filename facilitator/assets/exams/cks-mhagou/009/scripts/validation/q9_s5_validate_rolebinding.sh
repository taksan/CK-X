#!/bin/bash
# Item: RoleBinding john-role-binding binds Role john-role to the user john

NS="john"
B=$(kubectl get rolebinding john-role-binding -n "$NS" -o json 2>/dev/null)
[ -n "$B" ] || { echo "❌ RoleBinding john-role-binding not found in namespace $NS"; exit 1; }

echo "$B" | jq -e '.roleRef.kind == "Role" and .roleRef.name == "john-role" and ([.subjects[]? | select(.kind == "User" and .name == "john")] | length > 0)' >/dev/null \
  || { echo "❌ RoleBinding john-role-binding must bind the Role john-role to the User john"; exit 1; }

echo "✅ john-role-binding binds john-role to the user john"
exit 0
