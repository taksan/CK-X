#!/bin/bash
# The report on node01 lists the files that the process listening on port 389 had open: its log and
# the two data files it was started with (it may be the lsof output or any listing with the names)

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$NODE01"
FILE="${Q6_FILE:-/tmp/exam/mhagou-006-q6/files.txt}"

CONTENT=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat '$FILE'" 2>/dev/null)
[ -n "$CONTENT" ] || { echo "❌ The report '$FILE' does not exist on $NODE or is empty"; exit 1; }

MISSING=""
for f in /var/log/ldapd.log /var/lib/ldapd-data/records.dat /var/lib/ldapd-data/service.conf; do
  echo "$CONTENT" | grep -qF "$f" || MISSING="$MISSING $f"
done
[ -z "$MISSING" ] || { echo "❌ The report is not complete, these open files of the process on port 389 are missing:$MISSING"; exit 1; }

echo "✅ The report lists the open files of the process on port 389"
exit 0
