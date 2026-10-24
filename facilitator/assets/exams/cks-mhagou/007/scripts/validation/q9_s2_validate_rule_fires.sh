#!/bin/bash
# Item: the rule devmem fires when a process of the container reads /dev/mem (the file does not exist there)

source "$(dirname "$0")/../lib/falco-devmem.sh"
run_devmem_falco || exit 1
N=$(echo "$DEVMEM_JSON" | jq -c 'select(.rule == "devmem")' | wc -l)
[ "$N" -ge 1 ] || { echo "❌ No alert of the rule devmem was raised while the container tried to read /dev/mem (the file does not exist in the container: is the condition based on the failed open?)"; exit 1; }

echo "✅ The rule devmem fired $N time(s) for the reads of /dev/mem"
exit 0
