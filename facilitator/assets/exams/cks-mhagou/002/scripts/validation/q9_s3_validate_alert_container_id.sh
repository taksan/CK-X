#!/bin/bash
# The third field of the alert is the container id of the Pod (12 characters)

source "$(dirname "$0")/../lib/falco-shell.sh"
falco_shell_alert || exit 1

CID_FIELD=$(echo "$ALERT_OUTPUT" | awk -F, '{print $3}' | awk '{print $1}')
if [ "$CID_FIELD" != "$ALERT_CID" ]; then
  echo "❌ The third field of the alert is '${CID_FIELD:0:40}', expected the container id $ALERT_CID (alert: ${ALERT_OUTPUT:0:100})"
  exit 1
fi
echo "✅ The third field of the alert is the container id ($ALERT_CID)"
exit 0
