#!/bin/bash
# Item: the profile allows every syscall by default (SCMP_ACT_ALLOW) and blocks ptrace and
# process_vm_readv unconditionally with SCMP_ACT_ERRNO (combined or separate rules, any order)

source "$(dirname "$0")/../lib/seccomp-q6.sh"

P=$(q6_profile)
[ -n "$P" ] || { echo "❌ $Q6_PROFILE does not exist on the node of the Pod"; exit 1; }

if [ "$(echo "$P" | jq -r '.defaultAction // ""')" != "SCMP_ACT_ALLOW" ]; then
  echo "❌ defaultAction is '$(echo "$P" | jq -r '.defaultAction // "missing"')', expected SCMP_ACT_ALLOW"
  exit 1
fi

for name in ptrace process_vm_readv; do
  echo "$P" | jq -e --arg n "$name" 'any(.syscalls[]?; .action == "SCMP_ACT_ERRNO" and any(.names[]?; . == $n)
      and ((.args // []) | length == 0) and ((.includes // {}) | length == 0) and ((.excludes // {}) | length == 0)
      and ((.errnoRet // 1) | type == "number" and . > 0))' >/dev/null 2>&1 \
    || { echo "❌ $name is not blocked unconditionally with SCMP_ACT_ERRNO"; exit 1; }
done

# nothing else is blocked, and the two syscalls are not allowed again by another rule
echo "$P" | jq -e 'all(.syscalls[]?; if .action == "SCMP_ACT_ALLOW" then all(.names[]?; . != "ptrace" and . != "process_vm_readv")
      else all(.names[]?; . == "ptrace" or . == "process_vm_readv") end)' >/dev/null 2>&1 \
  || { echo "❌ The profile blocks other syscalls or allows ptrace/process_vm_readv again: all other syscalls must stay allowed"; exit 1; }

echo "✅ The profile allows everything except ptrace and process_vm_readv (SCMP_ACT_ERRNO)"
exit 0
