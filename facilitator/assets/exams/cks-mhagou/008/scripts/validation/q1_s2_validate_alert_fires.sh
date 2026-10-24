#!/bin/bash
# Item: the rule raises an alert when the container reads secret.txt (the alert mentions the file)

source "$(dirname "$0")/../lib/falco-q1.sh"
run_candidate_falco || exit 1

MATCHES=$(q1_container_events)
if [ -z "$MATCHES" ]; then
  echo "❌ No alert for a read of secret.txt from inside a container was raised in 25 s (the alert must expose the file name, for example fd.name, and the container id)"
  exit 1
fi

N=$(echo "$MATCHES" | wc -l)
echo "✅ $N alerts for reads of secret.txt from inside a container"
exit 0
