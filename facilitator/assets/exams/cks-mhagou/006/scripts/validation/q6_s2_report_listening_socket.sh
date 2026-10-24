#!/bin/bash
# The report also contains the listening socket of the process (lsof: TCP *:ldap (LISTEN) / *:389,
# or the socket:[inode] of /proc/<pid>/fd)

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$NODE01"
FILE="${Q6_FILE:-/tmp/exam/mhagou-006-q6/files.txt}"

STATE=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat /var/tmp/.ckx-q6-state" 2>/dev/null)
[ -n "$STATE" ] || { echo "❌ Internal state missing on $NODE"; exit 1; }
eval "$STATE"

CONTENT=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat '$FILE'" 2>/dev/null)
[ -n "$CONTENT" ] || { echo "❌ The report '$FILE' does not exist on $NODE or is empty"; exit 1; }
echo "$CONTENT" | grep -qF '/var/log/ldapd.log' || { echo "❌ The report does not list the open files of the process on port 389"; exit 1; }

if echo "$CONTENT" | grep -qE '(\*|[0-9.:]+):(ldap|389)\b|socket:\[?'"$Q6_SOCKET_INODE"'\]?'; then
  echo "✅ The report contains the listening socket"
  exit 0
fi
echo "❌ The report does not contain the listening socket of the process (TCP *:ldap (LISTEN))"
exit 1
