#!/bin/bash
# Run the standalone Falco configuration for a few seconds: the rule "Invoice process" must now
# report the processes spawned by the Pod invoice (it was hidden by the broad rule)

source "$(dirname "$0")/../lib/falco-q14.sh"
run_falco_q14 || exit 1

N=$(echo "$FALCO_OUT" | grep -cE "$INVOICE_RE")
if [ "$N" -lt 2 ]; then
  BROAD=$(echo "$FALCO_OUT" | grep -c 'BROAD | pod=invoice')
  echo "❌ The rule 'Invoice process' reported $N events in $FALCO_SECONDS seconds (the broad rule reported $BROAD events for the Pod invoice): with rule_matching: first only the first matching rule reports an event"
  exit 1
fi

echo "✅ The rule 'Invoice process' reports the processes of the Pod invoice ($N events in $FALCO_SECONDS seconds)"
exit 0
