#!/bin/bash
# Validate verified-tags.txt: exactly the tag whose signature verifies with cosign.pub

DIR="${Q5_DIR:-/tmp/exam/cks-005-q5}"
F="$DIR/verified-tags.txt"
[ -f "$DIR/.state" ] || { echo "❌ Internal state file missing"; exit 1; }
. "$DIR/.state"

[ -s "$F" ] || { echo "❌ $F does not exist or is empty"; exit 1; }
GOT=$(sed 's/[[:space:]]//g; /^$/d' "$F" | sort | tr '\n' ' ')

if [ "$GOT" != "$TRUSTED_TAG " ]; then
  echo "❌ The file lists '$GOT': only the tag whose signature is valid for cosign.pub belongs in it"
  exit 1
fi

echo "✅ verified-tags.txt contains only the tag signed with the trusted key"
exit 0
