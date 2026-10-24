#!/bin/bash
# Item: jacob can get, list and watch pods in dev-z, and nothing else on pods

NS="dev-z"
can() { kubectl auth can-i "$1" "$2" -n "$NS" --as=jacob 2>/dev/null; }

for verb in get list watch; do
  [ "$(can $verb pods)" = "yes" ] || { echo "❌ jacob cannot $verb pods in $NS"; exit 1; }
done
for verb in create update patch delete deletecollection; do
  [ "$(can $verb pods)" = "no" ] || { echo "❌ jacob can still $verb pods in $NS"; exit 1; }
done
[ "$(kubectl auth can-i create pods --subresource=exec -n "$NS" --as=jacob 2>/dev/null)" = "no" ] || { echo "❌ jacob can use pods/exec in $NS"; exit 1; }

echo "✅ jacob can get, list and watch pods in $NS and nothing more"
exit 0
