#!/bin/bash
# The provided profile (auditing.json) is installed under /var/lib/kubelet/seccomp on node01

source "$(dirname "$0")/../lib/nodes.sh"
NODE="${NODE01}"
EXPECTED='{"defaultAction":"SCMP_ACT_LOG"}'

FILES=$(ssh -o StrictHostKeyChecking=no "$NODE" "find /var/lib/kubelet/seccomp -type f 2>/dev/null" 2>/dev/null)
if [ -z "$FILES" ]; then
  echo "❌ No seccomp profile found under /var/lib/kubelet/seccomp on $NODE"
  exit 1
fi
for f in $FILES; do
  GOT=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat '$f'" 2>/dev/null | jq -cS . 2>/dev/null)
  if [ "$GOT" = "$EXPECTED" ]; then
    echo "✅ The profile is installed on $NODE as $f"
    exit 0
  fi
done
echo "❌ No file under /var/lib/kubelet/seccomp on $NODE has the content of auditing.json (defaultAction SCMP_ACT_LOG)"
exit 1
