#!/bin/bash
# The second field of the alert is the numeric user id of the shell (the process of the container runs as root: 0)

source "$(dirname "$0")/../lib/falco-shell.sh"
falco_shell_alert || exit 1

UID_FIELD=$(echo "$ALERT_OUTPUT" | awk -F, '{print $2}')
if [ "$UID_FIELD" != "0" ]; then
  echo "❌ The second field of the alert is '${UID_FIELD:0:40}', expected the user id 0 (alert: ${ALERT_OUTPUT:0:100})"
  exit 1
fi
echo "✅ The second field of the alert is the user id (0)"
exit 0
