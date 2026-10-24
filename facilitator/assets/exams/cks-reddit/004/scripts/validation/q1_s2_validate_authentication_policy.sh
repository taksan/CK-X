#!/bin/bash
# Validate CiliumNetworkPolicy team-dev-2: mutual authentication required for the egress of
# role=database Pods to role=api-service Pods, and that the handshake really happens (traffic
# flows and Cilium holds a SPIRE authentication entry for the two identities).

NS="team-dev"

JSON=$(kubectl get ciliumnetworkpolicy team-dev-2 -n "$NS" -o json 2>/dev/null)
if [ -z "$JSON" ]; then
  echo "❌ CiliumNetworkPolicy 'team-dev-2' not found in namespace '$NS'"
  exit 1
fi

if [ "$(echo "$JSON" | jq -r '.spec.endpointSelector.matchLabels.role // ""')" != "database" ]; then
  echo "❌ The policy must select the Pods with the label role=database"
  exit 1
fi

if ! echo "$JSON" | jq -e '[.spec.egress[]? | select(any(.toEndpoints[]?; .matchLabels.role == "api-service"))
      | select(.authentication.mode == "required")] | length > 0' >/dev/null; then
  echo "❌ The policy needs an egress rule to the Pods with role=api-service with authentication mode 'required'"
  exit 1
fi

DB_ID=$(kubectl get ciliumendpoint database-0 -n "$NS" -o jsonpath='{.status.identity.id}' 2>/dev/null)
API_ID=$(kubectl get ciliumendpoint -n "$NS" -l role=api-service -o jsonpath='{.items[0].status.identity.id}' 2>/dev/null)
IP=$(kubectl get pod -n "$NS" -l role=api-service -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)
if [ -z "$DB_ID" ] || [ -z "$API_ID" ] || [ -z "$IP" ]; then
  echo "❌ Unable to determine the Cilium identities of database-0 and api-service"
  exit 1
fi

for i in $(seq 1 10); do
  if kubectl exec -n "$NS" database-0 -- wget -q -T 4 -O /dev/null "http://$IP" >/dev/null 2>&1; then
    for agent in $(kubectl get pods -n kube-system -l k8s-app=cilium -o name); do
      if kubectl exec -n kube-system "$agent" -- cilium-dbg bpf auth list 2>/dev/null | awk -v s="$DB_ID" -v d="$API_ID" '$1 == s && $2 == d && $4 == "spire" {f=1} END {exit !f}'; then
        echo "✅ team-dev-2 requires mutual authentication and database-0 authenticated against api-service"
        exit 0
      fi
    done
  fi
  sleep 3
done

echo "❌ The policy is in place but database-0 cannot reach api-service with an authenticated connection"
exit 1
