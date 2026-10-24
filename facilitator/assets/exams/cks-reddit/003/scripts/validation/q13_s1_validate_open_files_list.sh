#!/bin/bash
# Validate the list of open files of the service was saved on node02 (it must include the
# log file the service had open)

NODE="node02"
FILE="${Q13_FILE:-/tmp/exam/cks-003-q13/files.txt}"

CONTENT=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat '$FILE'" 2>/dev/null)
if [ -z "$CONTENT" ]; then
  echo "❌ '$FILE' does not exist on $NODE or is empty"
  exit 1
fi

if ! echo "$CONTENT" | grep -q '/var/log/ldapd.log'; then
  echo "❌ The list does not contain the open files of the service on port 389 (expected /var/log/ldapd.log)"
  exit 1
fi

echo "✅ The open files of the service were saved in $FILE"
exit 0
