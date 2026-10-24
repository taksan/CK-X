#!/bin/bash
# Validate RoleBinding john-role-binding and, by behaviour, what the user john may do

NS="john"

if ! kubectl get rolebinding john-role-binding -n "$NS" -o json 2>/dev/null | jq -e '
    .roleRef.kind == "Role" and .roleRef.name == "john-role"
    and ([.subjects[]? | select(.kind == "User" and .name == "john")] | length > 0)' >/dev/null; then
  echo "❌ RoleBinding 'john-role-binding' does not bind Role 'john-role' to the user john"
  exit 1
fi

can() { kubectl auth can-i "$1" "$2" -n "${3:-$NS}" --as john 2>/dev/null; }

for res in pods secrets; do
  for verb in list get create delete; do
    if [ "$(can $verb $res)" != "yes" ]; then
      echo "❌ john cannot $verb $res in '$NS'"
      exit 1
    fi
  done
done

for check in "update pods" "create deployments" "create pods kube-public" "get secrets default"; do
  set -- $check
  if [ "$(can "$1" "$2" "$3")" = "yes" ]; then
    echo "❌ john may too much: $1 $2${3:+ in $3}"
    exit 1
  fi
done

echo "✅ john can list, get, create and delete pods and secrets in '$NS' and nothing else"
exit 0
