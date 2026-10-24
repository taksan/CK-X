#!/bin/bash
# Validate by behaviour: the Pod probe on node02 runs without an explicit seccomp profile and its
# process is confined by the runtime default profile (Seccomp: 2 filter mode)

source "$(dirname "$0")/../lib/nodes.sh"

NS="kubelet-lab"
J=$(kubectl get pod probe -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'probe' not found in namespace '$NS'"; exit 1; }
[ "$(echo "$J" | jq -r '.spec.nodeName')" = "$NODE02" ] || { echo "❌ Pod 'probe' does not run on $NODE02"; exit 1; }
[ "$(echo "$J" | jq -r '.status.phase')" = "Running" ] || { echo "❌ Pod 'probe' is not running"; exit 1; }
echo "$J" | jq -e '(.spec.securityContext.seccompProfile == null) and ([.spec.containers[].securityContext.seccompProfile] | all(. == null))' >/dev/null \
  || { echo "❌ The Pod sets a seccomp profile itself: the default must come from the kubelet"; exit 1; }

MODE=$(kubectl exec -n "$NS" probe -- sh -c "grep '^Seccomp:' /proc/1/status" 2>/dev/null | awk '{print $2}')
[ "$MODE" = "2" ] || { echo "❌ The Pod process has Seccomp mode '$MODE', expected 2 (was the Pod created after the kubelet restart?)"; exit 1; }

echo "✅ The Pod probe on $NODE02 is confined by the default seccomp profile"
exit 0
