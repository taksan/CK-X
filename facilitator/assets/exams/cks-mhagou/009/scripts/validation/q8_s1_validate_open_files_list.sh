#!/bin/bash
# Item: the names of the open files of the service were saved on the first worker node (they include the log file and the
# executable of the process)

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$NODE01"
FILE="${Q8_FILE:-/tmp/exam/mhagou-009-q8/files.txt}"

CONTENT=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat '$FILE'" 2>/dev/null)
[ -n "$CONTENT" ] || { echo "❌ '$FILE' does not exist on $NODE or is empty"; exit 1; }

for name in /var/log/ldapd.log /usr/local/sbin/ldapd; do
  echo "$CONTENT" | grep -q -- "$name" || { echo "❌ The list does not contain $name: it must hold the open files of the service on port 389"; exit 1; }
done

echo "✅ The open files of the service were saved in $FILE"
exit 0
