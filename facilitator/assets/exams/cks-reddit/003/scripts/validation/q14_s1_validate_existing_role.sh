#!/bin/bash
# Validate the ServiceAccount sa-dev-1 may only watch services in security (whatever Role
# gives it that), and that the Role of the other ServiceAccount was not touched.

NS="security"
SA="system:serviceaccount:$NS:sa-dev-1"
OPS="system:serviceaccount:$NS:sa-ops"

can() { kubectl auth can-i "$1" "$2" -n "$NS" --as "$3" 2>/dev/null; }

kubectl get pod web-pod -n "$NS" >/dev/null 2>&1 || { echo "❌ Pod 'web-pod' was deleted"; exit 1; }

if [ "$(can watch services "$SA")" != "yes" ]; then
  echo "❌ sa-dev-1 cannot watch services in '$NS'"
  exit 1
fi

for check in "get services" "list services" "create services" "delete services" "get pods" "list pods"; do
  set -- $check
  if [ "$(can "$1" "$2" "$SA")" = "yes" ]; then
    echo "❌ sa-dev-1 may still $1 $2 in '$NS': it must only be allowed to watch services"
    exit 1
  fi
done

# the other ServiceAccount keeps what it had
for check in "get pods" "list pods" "delete pods"; do
  set -- $check
  if [ "$(can "$1" "$2" "$OPS")" != "yes" ]; then
    echo "❌ sa-ops lost a permission ($1 $2): only the Role of sa-dev-1 had to be changed"
    exit 1
  fi
done

echo "✅ sa-dev-1 can only watch services in '$NS' and the Role of sa-ops is unchanged"
exit 0
