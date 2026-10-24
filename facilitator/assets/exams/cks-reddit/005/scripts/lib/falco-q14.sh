#!/bin/bash
# Source this file: runs the standalone Falco configuration of question 14 on node01 for a few
# seconds, without touching the Falco service and without writing any output file, and sets
# FALCO_OUT to what it printed. Returns 1 (with the first error line) if Falco does not start.

FALCO_DIR="${Q14_DIR:-/tmp/exam/cks-005-q14}"
FALCO_SECONDS="${Q14_SECONDS:-16}"

run_falco_q14() {
  FALCO_OUT=$(ssh -o StrictHostKeyChecking=no node01 \
    "timeout $FALCO_SECONDS falco -c '$FALCO_DIR/falco.yaml' -o file_output.enabled=false -o program_output.enabled=false -o http_output.enabled=false 2>&1")
  if ! echo "$FALCO_OUT" | grep -q 'Events detected'; then
    echo "❌ Falco does not run with $FALCO_DIR/falco.yaml: $(echo "$FALCO_OUT" | grep -iE 'error|invalid|cannot|fail' | head -1 | cut -c1-200)"
    return 1
  fi
}

# the lines produced by the rule "Invoice process" (timestamp,user,processName)
INVOICE_RE='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+(Z|[+-][0-9]{2}:?[0-9]{2}),[^,[:space:]]+,whoami$'
