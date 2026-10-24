#!/bin/bash
# The RUNNING kubelet of the control plane uses Webhook authorization (read from the configz of the
# kubelet, through the API server) and the configuration file says so

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$CONTROL_PLANE"
MODE=""
for i in $(seq 1 15); do
  MODE=$(kubectl get --raw "/api/v1/nodes/$NODE/proxy/configz" 2>/dev/null | jq -r '.kubeletconfig.authorization.mode // empty' 2>/dev/null)
  [ -n "$MODE" ] && break
  sleep 3
done
[ -n "$MODE" ] || { echo "❌ Unable to read the running configuration of the kubelet (is it running?)"; exit 1; }
[ "$MODE" = "Webhook" ] || { echo "❌ The running kubelet uses the authorization mode '$MODE', expected Webhook (was it restarted after the change?)"; exit 1; }

FILE=$(ssh -o StrictHostKeyChecking=no "$NODE" "yq '.authorization.mode' /var/lib/kubelet/config.yaml" 2>/dev/null)
[ "$FILE" = "Webhook" ] || { echo "❌ /var/lib/kubelet/config.yaml sets authorization.mode '$FILE', expected Webhook (the change would be lost at the next restart)"; exit 1; }

echo "✅ The kubelet uses Webhook authorization"
exit 0
