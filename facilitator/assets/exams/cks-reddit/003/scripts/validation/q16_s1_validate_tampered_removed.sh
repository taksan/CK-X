#!/bin/bash
# Validate the tampered copy was deleted and the genuine one was kept untouched

WORKDIR="/tmp/exam/cks-003-q16"
STATE="/tmp/exam/.cks-003-q16.state"

read -r TAMPERED GENUINE SHA < "$STATE" 2>/dev/null
if [ -z "$TAMPERED" ]; then
  echo "❌ The exercise state is missing (setup not run?)"
  exit 1
fi

if [ -e "$WORKDIR/$TAMPERED" ]; then
  echo "❌ The tampered binary was not deleted"
  exit 1
fi

if [ ! -f "$WORKDIR/$GENUINE" ]; then
  echo "❌ The genuine binary was deleted too: only the tampered one had to be removed"
  exit 1
fi

if [ "$(sha256sum "$WORKDIR/$GENUINE" | awk '{print $1}')" != "$SHA" ]; then
  echo "❌ The remaining binary was modified"
  exit 1
fi

echo "✅ The tampered binary was deleted and the genuine one is intact"
exit 0
