#!/bin/bash
# Item: jacob has no access at all to secrets, and no other resource of the namespace
# (credited once the pod permissions are reduced)

NS="dev-z"
can() { kubectl auth can-i "$1" "$2" -n "$NS" --as=jacob 2>/dev/null; }

[ "$(can delete pods)" = "no" ] || { echo "❌ The permissions of jacob are not reduced yet (he can still delete pods)"; exit 1; }
for verb in get list watch create update patch delete; do
  [ "$(can $verb secrets)" = "no" ] || { echo "❌ jacob can $verb secrets in $NS"; exit 1; }
done
# the full list of what jacob may do in the namespace
EXTRA=$(kubectl auth can-i --list -n "$NS" --as=jacob 2>/dev/null | awk 'NR>1 && $1 !~ /^(selfsubjectaccessreviews|selfsubjectrulesreviews|selfsubjectreviews)/ && $1 !~ /^\/|^\[/ {print $1}' | grep -v -E '^(pods|configmaps)$' | grep -v -E '^pods\.?$' | head -3)
[ -z "$EXTRA" ] || { echo "❌ jacob has permissions on other resources of $NS: $(echo $EXTRA | tr '\n' ' ')"; exit 1; }

echo "✅ jacob has no access to secrets (and nothing besides pods and configmaps)"
exit 0
