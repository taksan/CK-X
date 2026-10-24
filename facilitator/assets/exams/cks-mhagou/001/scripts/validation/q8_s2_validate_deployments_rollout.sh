#!/bin/bash
# Item (by behaviour): release-bot reads and updates/patches Deployments, but cannot create or delete them

NS="release-lab"
WHO="system:serviceaccount:$NS:release-bot"
can() { kubectl auth can-i "$@" --as="$WHO" -n "$NS" 2>/dev/null; }

for verb in get list watch update patch; do
  [ "$(can $verb deployments.apps)" = "yes" ] || { echo "❌ release-bot cannot $verb deployments"; exit 1; }
done
for verb in create delete deletecollection; do
  [ "$(can $verb deployments.apps)" = "no" ] || { echo "❌ release-bot can still $verb deployments: only get, list, watch, update and patch are allowed"; exit 1; }
done
[ "$(can patch statefulsets.apps)" = "no" ] || { echo "❌ release-bot can change StatefulSets: only Deployments were requested"; exit 1; }

echo "✅ release-bot can roll out Deployments but not create or delete them"
exit 0
