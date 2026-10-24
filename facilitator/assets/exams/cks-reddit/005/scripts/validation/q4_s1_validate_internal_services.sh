#!/bin/bash
# Validate the internal Services are ClusterIP (no node port, no external address) and still work

NS="exposed-lab"
for svc in reports admin; do
  J=$(kubectl get svc "$svc" -n "$NS" -o json 2>/dev/null)
  [ -n "$J" ] || { echo "❌ Service '$svc' was deleted: it had to be kept"; exit 1; }
  [ "$(echo "$J" | jq -r '.spec.type')" = "ClusterIP" ] || { echo "❌ Service '$svc' is of type $(echo "$J" | jq -r '.spec.type'), expected ClusterIP"; exit 1; }
  echo "$J" | jq -e '[.spec.ports[] | select(.nodePort != null)] | length == 0' >/dev/null || { echo "❌ Service '$svc' still has a nodePort"; exit 1; }
  [ "$(echo "$J" | jq -r '.spec.selector.app')" = "apps" ] || { echo "❌ The selector of '$svc' was changed"; exit 1; }
  [ -n "$(kubectl get endpoints "$svc" -n "$NS" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)" ] || { echo "❌ Service '$svc' has no endpoints anymore"; exit 1; }
done
[ "$(kubectl get svc reports -n "$NS" -o jsonpath='{.spec.ports[0].port}')" = "8080" ] && [ "$(kubectl get svc admin -n "$NS" -o jsonpath='{.spec.ports[0].port}')" = "9090" ] || { echo "❌ The ports of the Services were changed"; exit 1; }

echo "✅ reports and admin are internal (ClusterIP) and still work"
exit 0
