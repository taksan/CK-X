#!/bin/bash
# Source this file (question 6). Helpers: the Pod, its node and the profile read from that node.

source "$(dirname "${BASH_SOURCE[0]}")/nodes.sh"
Q6_NS="secure-runtime"
Q6_PROFILE="/var/lib/kubelet/seccomp/profiles/block-debug.json"

q6_pod_json() { kubectl get pod secure-app -n "$Q6_NS" -o json 2>/dev/null; }

# the profile as found on the node where the Pod runs (node01 unless the Pod was moved)
q6_profile() {
  local node
  node=$(q6_pod_json | jq -r --arg d "$NODE01" '.spec.nodeName // $d')
  ssh -o StrictHostKeyChecking=no "$node" "cat '$Q6_PROFILE'" 2>/dev/null
}
