#!/bin/bash
# Item: modified.txt holds the file name of the manifest whose SHA-512 no longer matches SHA512SUMS

DIR="${Q3_DIR:-/tmp/exam/mhagou-001-q3}"
[ -f "$DIR/.state" ] || { echo "❌ Internal state file missing"; exit 1; }
. "$DIR/.state"

[ -s "$DIR/modified.txt" ] || { echo "❌ $DIR/modified.txt does not exist or is empty"; exit 1; }
GOT=$(sed 's/[[:space:]]//g; /^$/d' "$DIR/modified.txt" | head -1)
GOT=$(basename "$GOT")
[ "$GOT" = "$TAMPERED" ] || { echo "❌ modified.txt contains '$GOT', which is not the manifest whose checksum differs (run sha512sum -c SHA512SUMS)"; exit 1; }

# the evidence must be untouched: the file was not restored/edited to make the check pass
if (cd "$DIR/manifests" && sha512sum -c ../SHA512SUMS 2>/dev/null | grep -q "^$TAMPERED: OK"); then
  echo "❌ $TAMPERED matches its checksum now: it was changed after the check; the manifests must be left as they are"
  exit 1
fi

echo "✅ modified.txt names the manifest with the wrong checksum ($TAMPERED)"
exit 0
