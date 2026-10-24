#!/bin/bash
# Item: the alerts of devmem have the priority NOTICE

source "$(dirname "$0")/../lib/falco-devmem.sh"
run_devmem_falco || exit 1
EV=$(echo "$DEVMEM_JSON" | jq -c 'select(.rule == "devmem")')
[ -n "$EV" ] || { echo "❌ The rule devmem raised no alert, nothing to credit"; exit 1; }
BAD=$(echo "$EV" | jq -r '.priority' | sort -u | grep -vix notice | head -1)
[ -z "$BAD" ] || { echo "❌ The priority of devmem is '$BAD', expected NOTICE"; exit 1; }

echo "✅ The priority of devmem is NOTICE"
exit 0
