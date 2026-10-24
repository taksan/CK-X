#!/bin/bash
# Source this file (questions 4 and 7): fetches the report of the candidate from a node
#   fetch_report NODE FILE   sets REPORT (the content); prints the reason and returns 1 when missing
#   iso_epoch STAMP          epoch seconds of a timestamp (ISO 8601 or time of day), empty when invalid

fetch_report() {
  REPORT=$(ssh -o StrictHostKeyChecking=no "$1" "cat '$2'" 2>/dev/null)
  if [ -z "$REPORT" ]; then
    echo "❌ The report '$2' does not exist on $1 or is empty"
    return 1
  fi
}

iso_epoch() {
  local s="$1"
  s="${s#[}"; s="${s%]}"
  # nanoseconds are not understood by every date: keep 9 digits at most, drop a +0000 style offset
  date -u -d "$(echo "$s" | sed -E 's/([0-9]{2}:[0-9]{2}:[0-9]{2})\.([0-9]{1,9})[0-9]*/\1/; s/\+0000$//; s/Z$//')" +%s 2>/dev/null
}
