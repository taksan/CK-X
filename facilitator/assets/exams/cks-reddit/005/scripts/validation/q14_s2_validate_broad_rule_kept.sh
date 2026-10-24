#!/bin/bash
# The fix must keep the broad rule working for the other Pod (the rule must not be deleted or
# crippled), together with the working rule for invoice

source "$(dirname "$0")/../lib/falco-q14.sh"
run_falco_q14 || exit 1

N=$(echo "$FALCO_OUT" | grep -cE "$INVOICE_RE")
if [ "$N" -lt 2 ]; then
  echo "❌ The rule 'Invoice process' still reports nothing ($N events): nothing to credit yet"
  exit 1
fi

M=$(echo "$FALCO_OUT" | grep -c 'BROAD | pod=mailer process=hostname')
if [ "$M" -lt 2 ]; then
  echo "❌ The broad rule reported only $M events for the Pod mailer in $FALCO_SECONDS seconds: the rule 'Any process in falco-lab' must keep reporting the processes of the other Pods"
  exit 1
fi

echo "✅ Both rules work: 'Invoice process' for invoice ($N events) and the broad rule for mailer ($M events)"
exit 0
