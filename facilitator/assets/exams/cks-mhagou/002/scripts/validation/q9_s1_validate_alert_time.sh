#!/bin/bash
# The alert of the terminal-shell rule starts with an ISO 8601 timestamp followed by a comma
# (output: <time>,<user id>,<container id>,<image repository>)

source "$(dirname "$0")/../lib/falco-shell.sh"
falco_shell_alert || exit 1

FIRST=$(echo "$ALERT_OUTPUT" | awk -F, '{print $1}')
if ! echo "$ALERT_OUTPUT" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+(Z|[+-][0-9]{2}:?[0-9]{2})?,'; then
  echo "❌ The alert output does not start with an ISO 8601 timestamp and a comma (alert: ${ALERT_OUTPUT:0:100})"
  exit 1
fi
echo "✅ The alert starts with the ISO 8601 timestamp ($FIRST)"
exit 0
