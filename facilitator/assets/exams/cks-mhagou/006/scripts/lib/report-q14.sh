#!/bin/bash
# Source this file: report_value KEY prints the value of KEY= in the report of node01 (first match)

source "$(dirname "${BASH_SOURCE[0]}")/nodes.sh"

DIR="${Q14_DIR:-/tmp/exam/mhagou-006-q14}"
NODE="$NODE01"
[ -f "$DIR/.expected" ] && . "$DIR/.expected"

report_value() {
  ssh -o StrictHostKeyChecking=no "$NODE" "cat '$DIR/report.txt'" 2>/dev/null | sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//Ip" | head -1 | tr -d '[:space:]'
}
