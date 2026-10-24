#!/bin/bash
# The incident file on node02 is not empty and every line has an event [time],[uid],[process] (the text
# that Falco puts around its output is accepted; headers and diagnostic lines are not)

source "$(dirname "$0")/../lib/capture-q5.sh"
load_capture || exit 1

[ "$FMT_OK" -ge 5 ] || { echo "❌ Only $FMT_OK lines have an event [time],[uid],[process] (at least 5 events are expected)"; exit 1; }
if [ "$FMT_OK" -ne "$TOTAL" ]; then
  BAD=$(echo "$RAW" | grep -vE "$TRIPLE" | grep . | head -1 | cut -c1-120)
  echo "❌ $((TOTAL - FMT_OK)) line(s) have no event in the format [time],[uid],[process], for example: $BAD"
  exit 1
fi

echo "✅ $FMT_OK events, every line has [time],[uid],[process]"
exit 0
