#!/bin/bash
# Item: the rule does not fire for reads of the same file made directly on the host
# (the run of the validator makes the host read the file 10 times)

source "$(dirname "$0")/../lib/falco-q1.sh"
run_candidate_falco || exit 1

if [ -z "$(q1_container_events)" ]; then
  echo "❌ The rule does not detect the container reads yet: nothing to judge for the host reads"
  exit 1
fi

HOST=$(q1_host_events)
if [ -n "$HOST" ]; then
  echo "❌ The rule also fires for a read of secret.txt made on the host (no container): add the container condition (container.id != host)"
  exit 1
fi

echo "✅ Reads of secret.txt on the host do not trigger the rule"
exit 0
