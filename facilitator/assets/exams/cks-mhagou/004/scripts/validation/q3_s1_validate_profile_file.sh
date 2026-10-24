#!/bin/bash
# Validate a seccomp profile exists on the second worker node under /var/lib/kubelet/seccomp that LOGS mkdir and
# mkdirat without blocking them, and does not block anything else

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$NODE02"

FILES=$(ssh -o StrictHostKeyChecking=no "$NODE" "find /var/lib/kubelet/seccomp -type f 2>/dev/null" 2>/dev/null)
[ -n "$FILES" ] || { echo "❌ No seccomp profile found under /var/lib/kubelet/seccomp on $NODE"; exit 1; }

for f in $FILES; do
  PROFILE=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat '$f'" 2>/dev/null)
  if echo "$PROFILE" | jq -e '
      def effective($n):
        ([.syscalls[]? | select(any(.names[]?; . == $n))] ) as $rules
        | if ($rules | length) == 0 then .defaultAction else ($rules | last | .action) end;
      .defaultAction == "SCMP_ACT_ALLOW"
      and effective("mkdir") == "SCMP_ACT_LOG"
      and effective("mkdirat") == "SCMP_ACT_LOG"
      and ([.syscalls[]? | select(.action != "SCMP_ACT_ALLOW" and .action != "SCMP_ACT_LOG")] | length == 0)
      and ([.syscalls[]? | select(.action == "SCMP_ACT_LOG") | .names[]?] | all(. == "mkdir" or . == "mkdirat"))' >/dev/null 2>&1; then
    echo "✅ $f logs only mkdir and mkdirat and allows everything else"
    exit 0
  fi
done

echo "❌ No profile on $NODE logs mkdir and mkdirat (SCMP_ACT_LOG) and nothing else, with defaultAction SCMP_ACT_ALLOW"
exit 1
