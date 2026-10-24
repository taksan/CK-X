#!/bin/bash
# Item (by behaviour): release-bot reads pods and pod logs, and can do nothing else with pods

NS="release-lab"
WHO="system:serviceaccount:$NS:release-bot"
can() { kubectl auth can-i "$@" --as="$WHO" -n "$NS" 2>/dev/null; }

for verb in get list watch; do
  [ "$(can $verb pods)" = "yes" ] || { echo "❌ release-bot cannot $verb pods"; exit 1; }
done
[ "$(can get pods --subresource=log)" = "yes" ] || { echo "❌ release-bot cannot read pod logs (pods/log)"; exit 1; }
for verb in create delete update patch deletecollection; do
  [ "$(can $verb pods)" = "no" ] || { echo "❌ release-bot can still $verb pods: only get, list and watch are allowed"; exit 1; }
done
[ "$(can create pods --subresource=exec)" = "no" ] || { echo "❌ release-bot can still run commands in Pods (pods/exec)"; exit 1; }

echo "✅ release-bot only reads pods and their logs"
exit 0
