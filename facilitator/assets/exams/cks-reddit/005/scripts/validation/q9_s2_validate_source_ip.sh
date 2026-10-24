#!/bin/bash
# Validate ip.txt holds the source IP of the request that deleted the Secret payment-gateway-key

DIR="${Q9_DIR:-/tmp/exam/cks-005-q9}"
[ -f "$DIR/.expected" ] || { echo "❌ Internal state file missing"; exit 1; }
. "$DIR/.expected"
[ -s "$DIR/ip.txt" ] || { echo "❌ $DIR/ip.txt does not exist or is empty"; exit 1; }

GOT=$(sed 's/[[:space:]]//g; /^$/d' "$DIR/ip.txt" | head -1)
[ "$GOT" = "$EXPECTED_IP" ] || { echo "❌ ip.txt contains '$GOT': that is not the source IP of the request that deleted the Secret"; exit 1; }

echo "✅ ip.txt holds the source IP of the deleting request"
exit 0
