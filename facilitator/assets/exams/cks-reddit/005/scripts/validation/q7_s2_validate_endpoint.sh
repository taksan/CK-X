#!/bin/bash
# Validate endpoint.txt holds the IP:port that the container process tries to connect to

DIR="${Q7_DIR:-/tmp/exam/cks-005-q7}"
[ -f "$DIR/.expected" ] || { echo "❌ Internal state file missing"; exit 1; }
. "$DIR/.expected"
[ -s "$DIR/endpoint.txt" ] || { echo "❌ $DIR/endpoint.txt does not exist or is empty"; exit 1; }

GOT=$(sed 's/[[:space:]]//g; /^$/d' "$DIR/endpoint.txt" | head -1)
[ "$GOT" = "$EXPECTED_ENDPOINT" ] || { echo "❌ endpoint.txt contains '$GOT', which is not the address the process connects to"; exit 1; }

echo "✅ endpoint.txt holds the address contacted by the Pod ledger-sync"
exit 0
