#!/bin/bash
# Item: Pod secure-nginx runs on node01 with the RuntimeDefault seccomp profile (spec and effective filter mode)
source "$(dirname "$0")/../lib/nodes.sh"

NS="secured-area"
J=$(kubectl get pod secure-nginx -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'secure-nginx' not found in namespace '$NS' (was it admitted by the restricted standard?)"; exit 1; }
[ "$(echo "$J" | jq -r '.status.phase')" = "Running" ] || { echo "❌ secure-nginx is not running (phase: $(echo "$J" | jq -r '.status.phase'))"; exit 1; }
[ "$(echo "$J" | jq -r '.spec.nodeName')" = "$NODE01" ] || { echo "❌ secure-nginx does not run on $NODE01"; exit 1; }

if ! echo "$J" | jq -e '(.spec.securityContext.seccompProfile.type == "RuntimeDefault") or all(.spec.containers[]; .securityContext.seccompProfile.type == "RuntimeDefault")' >/dev/null; then
  echo "❌ The Pod does not select the RuntimeDefault seccomp profile (Pod securityContext or every container)"
  exit 1
fi

MODE=$(kubectl exec -n "$NS" secure-nginx -- cat /proc/1/status 2>/dev/null | awk '/^Seccomp:/ {print $2}')
[ "$MODE" = "2" ] || { echo "❌ The container process has Seccomp mode '${MODE:-unknown}', expected 2 (filter)"; exit 1; }

echo "✅ secure-nginx runs on $NODE01 with the RuntimeDefault seccomp profile"
exit 0
