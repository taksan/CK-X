#!/bin/bash
# CiliumNetworkPolicy policy1 in the namespace app selects the Pods of app (all of them or id=app) and
# has an egress rule towards the Pods labelled id=data of the namespace data

J=$(kubectl get ciliumnetworkpolicy policy1 -n app -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ CiliumNetworkPolicy 'policy1' not found in namespace 'app'"; exit 1; }

echo "$J" | jq -e '(.spec.endpointSelector.matchLabels // {}) as $m | ($m | length) == 0 or ($m["id"] == "app") or ($m["k8s:id"] == "app")' >/dev/null \
  || { echo "❌ policy1 does not select the Pods of the namespace app (endpointSelector)"; exit 1; }
echo "$J" | jq -e '[.spec.egress[]?, .spec.egressDeny[]? | select(.toEndpoints != null or .toServices != null or .toCIDR != null)] | length > 0' >/dev/null \
  || { echo "❌ policy1 has no egress rule"; exit 1; }
echo "$J" | jq -e '[.spec.egress[]?.toEndpoints[]? | select(((.matchLabels // {}) | to_entries | map(.value) | index("data")) != null)] | length > 0' >/dev/null \
  || { echo "❌ policy1 has no egress rule towards the Pods labelled id=data of the namespace data"; exit 1; }

echo "✅ policy1 selects the Pods of app and allows egress towards the Pods id=data of the namespace data"
exit 0
