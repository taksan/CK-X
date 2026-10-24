#!/bin/bash
# Validate who.txt holds the user that successfully deleted the Secret payment-gateway-key

DIR="${Q9_DIR:-/tmp/exam/cks-005-q9}"
[ -f "$DIR/.expected" ] || { echo "❌ Internal state file missing"; exit 1; }
. "$DIR/.expected"
[ -s "$DIR/who.txt" ] || { echo "❌ $DIR/who.txt does not exist or is empty"; exit 1; }

GOT=$(sed 's/[[:space:]]//g; /^$/d' "$DIR/who.txt" | head -1)
[ "$GOT" = "$EXPECTED_ACTOR" ] || { echo "❌ who.txt contains '$GOT': that is not the user whose delete request succeeded"; exit 1; }

echo "✅ who.txt holds the user that deleted the Secret"
exit 0
