#!/bin/bash
# The events belong to exactly one of the two nginx containers (web-1 spawns uname, web-2 spawns
# hostname): the process of one of them is in the file and the process of the other one is not

source "$(dirname "$0")/../lib/capture-q5.sh"
load_capture || exit 1

W=$(echo "$NAMES" | grep -cx 'uname')
H=$(echo "$NAMES" | grep -cx 'hostname')
if [ "$W" -ge 3 ] && [ "$H" -eq 0 ]; then
  echo "✅ The file captures one nginx container only (web-1: $W events)"; exit 0
fi
if [ "$H" -ge 3 ] && [ "$W" -eq 0 ]; then
  echo "✅ The file captures one nginx container only (web-2: $H events)"; exit 0
fi
if [ "$W" -ge 1 ] && [ "$H" -ge 1 ]; then
  echo "❌ The file contains the processes of both nginx containers (uname: $W, hostname: $H): capture exactly one"; exit 1
fi
echo "❌ The file does not contain at least 3 events of one of the nginx containers (uname: $W, hostname: $H)"
exit 1
