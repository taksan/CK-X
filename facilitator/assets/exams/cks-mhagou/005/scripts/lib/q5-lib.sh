#!/bin/bash
# Helpers of the validators of question 5 (source with: source "$(dirname "$0")/../lib/q5-lib.sh").
#   check_record BINARY   0 when the file on k8s-api-server has a record for BINARY with the right
#                         SHA-256 of the installed binary; otherwise prints the reason and returns 1
#   binaries_untouched    0 when kubectl and kubelet still have the checksums recorded at the start

source "$(dirname "${BASH_SOURCE[0]}")/nodes.sh"
NODE="k8s-api-server"   # ssh alias of the control plane
DIR="/tmp/exam/mhagou-005-q5"

check_record() {
  local b="$1" out
  out=$(ssh -o StrictHostKeyChecking=no "$NODE" "BIN=$b DIR=$DIR bash -s" 2>/dev/null <<'EOF'
FILE="$DIR/verified-hashes.txt"
[ -s "$FILE" ] || { echo "MISSING-FILE"; exit 0; }
P=$(command -v "$BIN") || { echo "NO-BINARY"; exit 0; }
SUM=$(sha256sum "$P" | cut -d' ' -f1)
LINES=$(grep -E "(^|[^A-Za-z0-9_.-])$BIN([^A-Za-z0-9_.-]|$)" "$FILE" | grep -v "^[[:space:]]*#")
[ -n "$LINES" ] || { echo "NO-RECORD"; exit 0; }
BAD=0; GOOD=0
while IFS= read -r l; do
  d=$(echo "$l" | grep -oiE '[0-9a-f]{64}' | head -1)
  if [ -n "$d" ] && [ "$(echo "$d" | tr 'A-F' 'a-f')" = "$SUM" ]; then GOOD=1; else BAD=1; fi
done <<< "$LINES"
if [ "$GOOD" = 1 ] && [ "$BAD" = 0 ]; then echo "OK"; elif [ "$GOOD" = 1 ]; then echo "MIXED"; else echo "WRONG"; fi
EOF
)
  case "$out" in
    OK) return 0 ;;
    MISSING-FILE) echo "❌ $DIR/verified-hashes.txt does not exist or is empty on $CONTROL_PLANE" ;;
    NO-RECORD) echo "❌ The file has no record for $b (each record needs the SHA-256 digest and the binary name or full path)" ;;
    WRONG) echo "❌ The SHA-256 recorded for $b is not the checksum of the installed binary on $CONTROL_PLANE" ;;
    MIXED) echo "❌ The file also holds a record for $b whose digest is wrong" ;;
    *) echo "❌ Unable to check the record for $b on $CONTROL_PLANE ($out)" ;;
  esac
  return 1
}

binaries_untouched() {
  ssh -o StrictHostKeyChecking=no "$NODE" "DIR=$DIR bash -s" 2>/dev/null <<'EOF'
[ -s "$DIR/.expected" ] || exit 2
while read -r b p sum; do
  [ "$(sha256sum "$p" 2>/dev/null | cut -d' ' -f1)" = "$sum" ] || exit 1
done < "$DIR/.expected"
exit 0
EOF
}
