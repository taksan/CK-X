#!/bin/bash
# Item: the rule does not fire for reads of the same file made directly on the host
# (the run of the validator makes the host read the file 10 times)

source "$(dirname "$0")/../lib/falco-q1.sh"
run_candidate_falco || exit 1

# the rule(s) that detect the container reads
RULES=$(q1_container_events | jq -r '.rule' | sort -u)
if [ -z "$RULES" ]; then
  echo "❌ The rule does not detect the container reads yet: nothing to judge for the host reads"
  exit 1
fi

# an alert of one of those rules about secret.txt that was NOT raised for a container
HOST=$(echo "$FALCO_JSON" | jq -c --argjson rules "$(echo "$RULES" | jq -R . | jq -sc .)" '
  select(.rule as $r | $rules | index($r) != null)
  | select((.output_fields // {}) | (."fd.name" // "" | endswith("secret.txt")))
  | select((((.output_fields // {})."container.id" // "host") as $c | $c == "host" or $c == "<NA>" or $c == ""))' 2>/dev/null)

if [ -n "$HOST" ]; then
  echo "❌ The rule also fires for a read of secret.txt made on the host (no container): add the container condition (container.id != host)"
  exit 1
fi

echo "✅ Reads of secret.txt on the host do not trigger the rule"
exit 0
