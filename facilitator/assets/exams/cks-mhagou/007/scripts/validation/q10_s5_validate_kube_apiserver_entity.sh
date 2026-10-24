#!/bin/bash
# Item: a Cilium policy selects env=dev and allows egress to the entity kube-apiserver (toEntities)

OK=0
J=$( { kubectl get ciliumnetworkpolicies -A -o json; kubectl get ciliumclusterwidenetworkpolicies -o json; } 2>/dev/null | jq -s '[.[].items[]?]')
echo "$J" | jq -e '[.[] | (.spec // empty), (.specs[]? // empty)
  | select((.endpointSelector.matchLabels.env // .endpointSelector.matchLabels["k8s:env"] // "") == "dev"
           or ((.endpointSelector.matchExpressions // []) | any(.key == "env" and (.values // []) | index("dev") != null)))
  | select((.egress // []) | any((.toEntities // []) | index("kube-apiserver") != null))] | length > 0' >/dev/null \
  && OK=1
[ "$OK" = "1" ] || { echo "❌ No Cilium policy selects the Pods with env=dev and allows egress with toEntities: [kube-apiserver]"; exit 1; }

echo "✅ A Cilium policy allows env=dev Pods to reach the entity kube-apiserver"
exit 0
