#!/bin/bash
# Item: the alert holds the file path and the command that read the file

source "$(dirname "$0")/../lib/falco-q1.sh"
run_candidate_falco || exit 1

MATCHES=$(q1_container_events)
[ -n "$MATCHES" ] || { echo "❌ No alert for reads of secret.txt from inside a container was raised"; exit 1; }

# the command: the process name or the command line of the reader (cat), in the output text or in the fields
if ! echo "$MATCHES" | jq -e 'select((.output + (.output_fields | tostring)) | test("cat"))' >/dev/null 2>&1; then
  echo "❌ The alert does not show the command that read the file (for example %proc.cmdline or %proc.name)"
  exit 1
fi

# the file: the path (the reads are of /data/secret.txt inside the container)
if ! echo "$MATCHES" | jq -e 'select((.output + (.output_fields | tostring)) | test("/secret.txt"))' >/dev/null 2>&1; then
  echo "❌ The alert does not show the path of the file (for example %fd.name)"
  exit 1
fi

echo "✅ The alert shows the file path and the command (cat)"
exit 0
