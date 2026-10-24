#!/bin/bash
# Item: the alert identifies the container (its id, or its name)

source "$(dirname "$0")/../lib/falco-q1.sh"
run_candidate_falco || exit 1

CID=$(q1_container_id)
[ -n "$CID" ] || { echo "❌ Pod rogue-pod has no container id (was it deleted?)"; exit 1; }

MATCHES=$(q1_container_events)
[ -n "$MATCHES" ] || { echo "❌ No alert for reads of secret.txt from inside a container was raised"; exit 1; }

# the alert text and fields together must hold the container id (12 characters are enough) or its name
if echo "$MATCHES" | jq -e --arg cid "$CID" 'select(((.output + (.output_fields | tostring)) | (contains($cid) or contains("snooper-container"))))' >/dev/null 2>&1; then
  echo "✅ The alert identifies the container (id $CID / name snooper-container)"
  exit 0
fi

echo "❌ The alert does not identify the container: put the container id or name in the output (for example %container.id or %container.name)"
exit 1
