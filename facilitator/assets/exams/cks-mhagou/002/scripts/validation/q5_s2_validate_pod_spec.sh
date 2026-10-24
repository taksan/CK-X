#!/bin/bash
# Pod nginx-auditing (alpha): nginx image, pinned to node01, Localhost seccomp profile whose file
# exists on node01 (pod level or container level)

source "$(dirname "$0")/../lib/nodes.sh"
NS="alpha"
J=$(kubectl get pod nginx-auditing -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Pod 'nginx-auditing' not found in namespace '$NS'"; exit 1; }

echo "$J" | jq -e '[.spec.containers[].image] | any(startswith("nginx") or test("/nginx(:|$)"))' >/dev/null || { echo "❌ The Pod does not use the nginx image"; exit 1; }
[ "$(echo "$J" | jq -r '.spec.nodeName')" = "${NODE01}" ] || { echo "❌ The Pod must run on ${NODE01}, where the profile is installed"; exit 1; }

REL=$(echo "$J" | jq -r '(.spec.securityContext.seccompProfile // (.spec.containers[0].securityContext.seccompProfile) | select(.type == "Localhost") | .localhostProfile) // empty')
[ -n "$REL" ] || { echo "❌ The Pod does not use a Localhost seccomp profile"; exit 1; }

if ! ssh -o StrictHostKeyChecking=no node01 "test -f '/var/lib/kubelet/seccomp/$REL'" 2>/dev/null; then
  echo "❌ The profile '$REL' (relative to /var/lib/kubelet/seccomp) does not exist on ${NODE01}"
  exit 1
fi

echo "✅ nginx-auditing runs on ${NODE01} with the Localhost seccomp profile $REL"
exit 0
