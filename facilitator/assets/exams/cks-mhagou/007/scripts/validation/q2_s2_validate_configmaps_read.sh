#!/bin/bash
# Item: jacob can get and list configmaps (credited once the pod permissions are reduced)

NS="dev-z"
can() { kubectl auth can-i "$1" "$2" -n "$NS" --as=jacob 2>/dev/null; }

[ "$(can delete pods)" = "no" ] || { echo "❌ The pod permissions of jacob are not reduced yet (he can still delete pods)"; exit 1; }
for verb in get list; do
  [ "$(can $verb configmaps)" = "yes" ] || { echo "❌ jacob cannot $verb configmaps in $NS"; exit 1; }
done
for verb in create update patch delete watch; do
  [ "$(can $verb configmaps)" = "no" ] || { echo "❌ jacob may $verb configmaps in $NS: only get and list were requested"; exit 1; }
done

echo "✅ jacob can get and list configmaps in $NS and nothing more"
exit 0
