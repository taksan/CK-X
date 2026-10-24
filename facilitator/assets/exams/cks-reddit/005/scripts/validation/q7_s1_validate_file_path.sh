#!/bin/bash
# Validate file.txt holds the path of the file the container process creates and reads

DIR="${Q7_DIR:-/tmp/exam/cks-005-q7}"
[ -f "$DIR/.expected" ] || { echo "❌ Internal state file missing"; exit 1; }
. "$DIR/.expected"
[ -s "$DIR/file.txt" ] || { echo "❌ $DIR/file.txt does not exist or is empty"; exit 1; }

GOT=$(sed 's/[[:space:]]//g; /^$/d' "$DIR/file.txt" | head -1)
[ "$GOT" = "$EXPECTED_FILE" ] || { echo "❌ file.txt contains '$GOT', which is not the file used by the process"; exit 1; }

echo "✅ file.txt holds the path used by the process of the Pod ledger-sync"
exit 0
