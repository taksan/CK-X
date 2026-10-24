#!/bin/bash
# Behaviour: an unauthenticated HTTPS request to the kubelet of the control plane (/pods on 10250) is
# rejected with HTTP 401

source "$(dirname "$0")/../lib/nodes.sh"

IP=$(kubectl get node "$CONTROL_PLANE" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
[ -n "$IP" ] || { echo "❌ Unable to read the address of the node $CONTROL_PLANE"; exit 1; }

CODE=""
for i in $(seq 1 15); do
  CODE=$(curl -sk -m 5 -o /dev/null -w '%{http_code}' "https://$IP:10250/pods" 2>/dev/null)
  [ "$CODE" = "401" ] && break
  sleep 3
done
[ "$CODE" = "401" ] || { echo "❌ An unauthenticated request to https://$IP:10250/pods returned HTTP ${CODE:-none}, expected 401 (anonymous authentication is still enabled?)"; exit 1; }

echo "✅ Anonymous requests to the kubelet are rejected with HTTP 401"
exit 0
