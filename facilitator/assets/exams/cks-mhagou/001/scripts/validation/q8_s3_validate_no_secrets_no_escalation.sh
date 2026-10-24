#!/bin/bash
# Item (by behaviour): release-bot cannot read secrets or configmaps and cannot escalate through RBAC

NS="release-lab"
WHO="system:serviceaccount:$NS:release-bot"
can() { kubectl auth can-i "$@" --as="$WHO" -n "$NS" 2>/dev/null; }

# credited only once the broad access is gone (the untouched namespace allows everything) and while the
# requested access still exists (removing every permission is not a solution)
[ "$(can delete pods)" = "no" ] || { echo "❌ release-bot can still delete pods: the Role is still too broad"; exit 1; }
[ "$(can get pods)" = "yes" ] || { echo "❌ release-bot lost the permissions that were requested (it cannot get pods)"; exit 1; }

for res in secrets configmaps serviceaccounts; do
  for verb in get list; do
    [ "$(can $verb $res)" = "no" ] || { echo "❌ release-bot can still $verb $res"; exit 1; }
  done
done
for res in roles rolebindings; do
  [ "$(can create $res.rbac.authorization.k8s.io)" = "no" ] || { echo "❌ release-bot can still create $res (privilege escalation)"; exit 1; }
done
[ "$(can bind roles.rbac.authorization.k8s.io)" = "no" ] || { echo "❌ release-bot can still bind roles"; exit 1; }
[ "$(can escalate roles.rbac.authorization.k8s.io)" = "no" ] || { echo "❌ release-bot can still escalate roles"; exit 1; }

echo "✅ release-bot cannot read secrets or configmaps and cannot escalate"
exit 0
