#!/bin/bash
# Item: Falco loads the candidate's rule file and runs with it (standalone run on node01)

source "$(dirname "$0")/../lib/falco-q1.sh"
run_candidate_falco || exit 1

echo "✅ Falco loads $Q1_DIR/catch-rogue.yaml and runs with it"
exit 0
