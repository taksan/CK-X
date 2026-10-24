#!/bin/bash
# The events were recorded after the exam started and cover at least 15 seconds (a capture of at
# least 30 seconds; Falco needs a few seconds to start)

source "$(dirname "$0")/../lib/capture-q5.sh"
load_capture || exit 1

STARTED=$(ssh -o StrictHostKeyChecking=no "$NODE" "cat /tmp/exam/mhagou-006-q5/.started" 2>/dev/null)
T_START=$(date -u -d "$STARTED" +%s 2>/dev/null || echo 0)
TODAY=$(date -u +%Y-%m-%d)

EPOCHS=""
while read -r line; do
  t=$(echo "$line" | sed -E 's/^\[([^]]*)\].*/\1/')
  case "$t" in
    [0-9][0-9][0-9][0-9]-*) e=$(date -u -d "$t" +%s 2>/dev/null) ;;
    [0-9][0-9]:[0-9][0-9]:[0-9][0-9]*) e=$(date -u -d "$TODAY ${t%%.*}" +%s 2>/dev/null) ;;
    *) e="" ;;
  esac
  [ -n "$e" ] && EPOCHS="$EPOCHS$e"$'\n'
done < <(echo "$CAPTURE" | grep -E "$RE")

FIRST=$(echo "$EPOCHS" | grep . | sort -n | head -1)
LAST=$(echo "$EPOCHS" | grep . | sort -n | tail -1)
[ -n "$FIRST" ] || { echo "❌ The timestamps of the events cannot be read (time or ISO 8601 date)"; exit 1; }
[ "$FIRST" -ge $((T_START - 2)) ] || { echo "❌ The file contains events recorded before the exam started"; exit 1; }
SPAN=$((LAST - FIRST))
[ "$SPAN" -ge 15 ] || { echo "❌ The events cover only $SPAN seconds, a capture of at least 30 seconds is expected"; exit 1; }

echo "✅ The events cover $SPAN seconds and were recorded during the exam"
exit 0
