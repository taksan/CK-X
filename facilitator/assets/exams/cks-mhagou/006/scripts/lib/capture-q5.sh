#!/bin/bash
# Source this file: loads the capture file of question 5 from node02 and sets
#   RAW      the lines of the file
#   TOTAL    number of (non empty) lines
#   CAPTURE  the [time],[uid],[process] part of every line that has one (Falco decorates its output: a
#            "<time>: <priority>" prefix and, by default, the container fields after the output, which are
#            accepted; a line without the part is a header or a diagnostic message)
#   FMT_OK   number of lines that have the part
#   NAMES    process names of those lines

source "$(dirname "${BASH_SOURCE[0]}")/nodes.sh"

NODE="$NODE02"
FILE="${Q5_FILE:-/tmp/exam/mhagou-006-q5/incident.txt}"
# the part of a line: [time],[uid],[process] (no other bracket inside)
TRIPLE='\[[^],[]+\],\[[0-9]+\],\[[^],[]+\]'
RE="^$TRIPLE\$"

load_capture() {
  RAW=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat '$FILE'" 2>/dev/null)
  if [ -z "$RAW" ]; then
    echo "❌ The incident file '$FILE' does not exist on $NODE or is empty"
    return 1
  fi
  TOTAL=$(echo "$RAW" | grep -c .)
  CAPTURE=$(echo "$RAW" | while IFS= read -r line; do echo "$line" | grep -oE "$TRIPLE" | head -1; done | grep .)
  FMT_OK=$(echo "$CAPTURE" | grep -cE "$RE")
  NAMES=$(echo "$CAPTURE" | grep -E "$RE" | sed -E 's/^\[[^]]*\],\[[0-9]+\],\[([^]]*)\]$/\1/')
}
