#!/bin/bash
# Pod secure (nginx) runs in gvisor-lab on node02 with the RuntimeClass hardened

source "$(dirname "$0")/../lib/nodes.sh"

NS="gvisor-lab"
J=$(kubectl get pod secure -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'secure' not found in namespace '$NS'"; exit 1; }

[ "$(echo "$J" | jq -r '.spec.runtimeClassName // ""')" = "hardened" ] || { echo "❌ Pod 'secure' does not use runtimeClassName: hardened"; exit 1; }
echo "$J" | jq -e 'any(.spec.containers[]; .image | test("^(docker.io/library/)?nginx(:|$)"))' >/dev/null || { echo "❌ Pod 'secure' does not use the nginx image"; exit 1; }
[ "$(echo "$J" | jq -r '.spec.nodeName // ""')" = "$NODE02" ] || { echo "❌ Pod 'secure' does not run on $NODE02 (node: $(echo "$J" | jq -r '.spec.nodeName // "none"'))"; exit 1; }
[ "$(echo "$J" | jq -r '.status.phase')" = "Running" ] || { echo "❌ Pod 'secure' is not running (phase: $(echo "$J" | jq -r '.status.phase'))"; exit 1; }

echo "✅ Pod 'secure' (nginx) runs on $NODE02 with the RuntimeClass hardened"
exit 0
