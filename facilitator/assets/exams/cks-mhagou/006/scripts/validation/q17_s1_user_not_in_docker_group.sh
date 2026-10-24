#!/bin/bash
# The user developer is not a member of the group docker any more (the user and the group still exist)

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$NODE02"
R=$(ssh -o StrictHostKeyChecking=no "$NODE" 'id developer >/dev/null 2>&1 && echo user-ok; getent group docker >/dev/null && echo group-ok; id -nG developer 2>/dev/null' 2>/dev/null)
echo "$R" | grep -q user-ok || { echo "❌ The user 'developer' does not exist any more: only the membership had to be removed"; exit 1; }
echo "$R" | grep -q group-ok || { echo "❌ The group 'docker' does not exist any more: only the membership had to be removed"; exit 1; }
echo "$R" | tail -1 | tr ' ' '\n' | grep -qx docker && { echo "❌ The user 'developer' is still a member of the group docker"; exit 1; }

echo "✅ The user developer is no longer in the group docker"
exit 0
