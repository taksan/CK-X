#!/bin/bash
# Validate by behaviour: curlpod reaches nginx and Cilium holds a SPIRE authentication entry for the
# two identities (the mutual authentication handshake really happened)

NS="cilium-lab"

CLIENT_ID=$(kubectl get ciliumendpoint curlpod -n "$NS" -o jsonpath='{.status.identity.id}' 2>/dev/null)
SERVER_ID=$(kubectl get ciliumendpoint -n "$NS" -l app=nginx -o jsonpath='{.items[0].status.identity.id}' 2>/dev/null)
if [ -z "$CLIENT_ID" ] || [ -z "$SERVER_ID" ]; then
  echo "❌ Unable to determine the Cilium identities of curlpod and nginx"
  exit 1
fi

# no policy requiring authentication: nothing to credit
kubectl get ciliumnetworkpolicy -n "$NS" -o json 2>/dev/null \
  | jq -e '[.items[] | .spec.ingress[]? | select(.authentication.mode == "required")] | length > 0' >/dev/null \
  || { echo "❌ No ingress rule requires authentication: the traffic is not authenticated"; exit 1; }

for i in $(seq 1 12); do
  if kubectl exec -n "$NS" curlpod -- wget -q -T 4 -O /dev/null http://nginx.cilium-lab.svc.cluster.local >/dev/null 2>&1; then
    for agent in $(kubectl get pods -n kube-system -l k8s-app=cilium -o name); do
      if kubectl exec -n kube-system "$agent" -- cilium-dbg bpf auth list 2>/dev/null \
         | awk -v a="$CLIENT_ID" -v b="$SERVER_ID" '$4 == "spire" && (($1 == a && $2 == b) || ($1 == b && $2 == a)) {f=1} END {exit !f}'; then
        echo "✅ curlpod reaches nginx and Cilium holds a SPIRE authentication entry for the two identities"
        exit 0
      fi
    done
  fi
  sleep 3
done

echo "❌ curlpod cannot reach nginx on port 80 through an authenticated connection (no HTTP answer or no authentication entry)"
exit 1
