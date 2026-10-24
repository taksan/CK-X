#!/bin/bash
# Item: the user developer is not a member of the group docker on the second worker node

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$NODE02"
GROUPS_OF=$(ssh -o StrictHostKeyChecking=no "$NODE" "id -nG developer" 2>/dev/null)
[ -n "$GROUPS_OF" ] || { echo "❌ The user developer does not exist on $NODE (it must stay)"; exit 1; }

if echo " $GROUPS_OF " | grep -q " docker "; then
  echo "❌ developer is still a member of the group docker (groups: $GROUPS_OF)"
  exit 1
fi

echo "✅ developer is not a member of docker"
exit 0
