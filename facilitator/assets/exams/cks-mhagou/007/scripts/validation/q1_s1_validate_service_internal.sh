#!/bin/bash
# Item: the Service nginx-external is not exposed outside the cluster any more

NS="exposure-lab"
J=$(kubectl get service nginx-external -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Service 'nginx-external' not found in namespace '$NS' (it must be kept, not deleted)"; exit 1; }

TYPE=$(echo "$J" | jq -r '.spec.type')
[ "$TYPE" = "ClusterIP" ] || { echo "❌ Service nginx-external is of type $TYPE, expected ClusterIP"; exit 1; }
echo "$J" | jq -e '[.spec.ports[] | select(.nodePort != null)] | length == 0' >/dev/null || { echo "❌ Service nginx-external still has a nodePort"; exit 1; }
echo "$J" | jq -e '((.spec.externalIPs // []) | length == 0) and ((.status.loadBalancer.ingress // []) | length == 0)' >/dev/null \
  || { echo "❌ Service nginx-external still has external IPs or a load balancer address"; exit 1; }

echo "✅ Service nginx-external is ClusterIP only (no node port, no external address)"
exit 0
