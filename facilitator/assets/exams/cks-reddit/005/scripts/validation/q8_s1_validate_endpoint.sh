#!/bin/bash
# Validate endpoint.txt holds the IP:port that the suspicious process of node02 connects to

source "$(dirname "$0")/../lib/nodes.sh"

DIR="${Q8_DIR:-/tmp/exam/cks-005-q8}"
STATE=$(ssh -o StrictHostKeyChecking=no node02 'cat /var/tmp/.ckx-q8-state' 2>/dev/null)
[ -n "$STATE" ] || { echo "❌ Internal state missing on $NODE02"; exit 1; }
eval "$STATE"
[ -s "$DIR/endpoint.txt" ] || { echo "❌ $DIR/endpoint.txt does not exist or is empty"; exit 1; }

GOT=$(sed 's/[[:space:]]//g; /^$/d' "$DIR/endpoint.txt" | head -1)
[ "$GOT" = "$Q8_IP:$Q8_PORT" ] || { echo "❌ endpoint.txt contains '$GOT', which is not the address the process connects to"; exit 1; }

echo "✅ endpoint.txt holds the address contacted by the suspicious process"
exit 0
