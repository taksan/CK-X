#!/bin/bash
# Item: no other group of developer was removed (credited only once docker was removed)

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$NODE02"
GROUPS_OF=$(ssh -o StrictHostKeyChecking=no "$NODE" "id -nG developer" 2>/dev/null)
[ -n "$GROUPS_OF" ] || { echo "❌ The user developer does not exist on $NODE"; exit 1; }

if echo " $GROUPS_OF " | grep -q " docker "; then
  echo "❌ developer is still in the group docker: nothing to credit yet"
  exit 1
fi

for g in developer developers auditors; do
  echo " $GROUPS_OF " | grep -q " $g " || { echo "❌ developer lost the group $g (groups: $GROUPS_OF): only docker had to be removed"; exit 1; }
done

echo "✅ developer was removed from docker only (groups: $GROUPS_OF)"
exit 0
