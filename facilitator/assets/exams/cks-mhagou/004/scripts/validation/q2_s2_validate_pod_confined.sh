#!/bin/bash
# Validate by reading the kernel state inside the Pod: hello-apparmor runs on the first worker node and its
# container is confined by a custom AppArmor profile in enforce mode (not unconfined, not the
# runtime default)

source "$(dirname "$0")/../lib/nodes.sh"

NS="write-guard"
POD="hello-apparmor"

J=$(kubectl get pod "$POD" -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod '$POD' not found in namespace '$NS'"; exit 1; }
[ "$(echo "$J" | jq -r '.spec.nodeName')" = "$NODE01" ] || { echo "❌ Pod '$POD' does not run on $NODE01 (the profile is loaded there)"; exit 1; }
[ "$(echo "$J" | jq -r '.status.phase')" = "Running" ] || { echo "❌ Pod '$POD' is not running (phase $(echo "$J" | jq -r '.status.phase')): is the profile loaded on $NODE01?"; exit 1; }

STATE=$(kubectl exec -n "$NS" "$POD" -- sh -c 'cat /proc/self/attr/apparmor/current 2>/dev/null || cat /proc/self/attr/current' 2>/dev/null)
case "$STATE" in
  *" (enforce)") ;;
  *) echo "❌ The container is not confined in enforce mode (AppArmor state: '${STATE:-unknown}')"; exit 1 ;;
esac
PROFILE=${STATE% (enforce)}
case "$PROFILE" in
  unconfined|cri-containerd.apparmor.d|docker-default) echo "❌ The container uses the default/unconfined profile ('$PROFILE'): reference the loaded profile in the Pod"; exit 1 ;;
esac

echo "✅ Pod '$POD' on $NODE01 is confined by the AppArmor profile '$PROFILE' (enforce)"
exit 0
