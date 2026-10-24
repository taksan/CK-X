#!/bin/bash
# Validate a seccomp profile exists on node01 under /var/lib/kubelet/seccomp that blocks mkdir
# and mkdirat and allows everything else

NODE="node01"

FILES=$(ssh -o StrictHostKeyChecking=no "$NODE" "find /var/lib/kubelet/seccomp -type f 2>/dev/null" 2>/dev/null)
if [ -z "$FILES" ]; then
  echo "❌ No seccomp profile found under /var/lib/kubelet/seccomp on $NODE"
  exit 1
fi

for f in $FILES; do
  PROFILE=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat '$f'" 2>/dev/null)
  if echo "$PROFILE" | jq -e '
      .defaultAction == "SCMP_ACT_ALLOW"
      and ([.syscalls[]? | select(.action != "SCMP_ACT_ALLOW") | .names[]] | (index("mkdir") != null and index("mkdirat") != null))' >/dev/null 2>&1; then
    echo "✅ $f blocks mkdir and mkdirat and allows all other syscalls"
    exit 0
  fi
done

echo "❌ No profile blocks mkdir and mkdirat while allowing the other syscalls (defaultAction SCMP_ACT_ALLOW)"
exit 1
