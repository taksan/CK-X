#!/bin/bash
# Item: the output of devmem is "Shell (container_id=<id of the container>)"

source "$(dirname "$0")/../lib/falco-devmem.sh"
run_devmem_falco || exit 1
ID=$(devmem_container_id)
EV=$(echo "$DEVMEM_JSON" | jq -c 'select(.rule == "devmem")')
[ -n "$EV" ] || { echo "❌ The rule devmem raised no alert, nothing to check"; exit 1; }
if echo "$EV" | jq -e --arg id "$ID" 'select((.output // "") | contains("Shell (container_id=" + $id + ")"))' >/dev/null; then
  echo "✅ The output of devmem is Shell (container_id=$ID)"
  exit 0
fi
GOT=$(echo "$EV" | jq -r '.output' | head -1 | cut -c1-140)
echo "❌ The output of devmem must contain 'Shell (container_id=$ID)', Falco printed: $GOT"
exit 1
