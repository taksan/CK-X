#!/bin/bash
# Item: the binaries that do not match the reference are deleted

DIR="${Q11_DIR:-/tmp/exam/mhagou-007-q11}"
[ -f "$DIR/.tampered" ] || { echo "❌ Internal state file missing"; exit 1; }
for n in $(cat "$DIR/.tampered"); do
  [ ! -e "$DIR/bin/$n" ] || { echo "❌ $n does not match its checksum in reference.sha512 and must be deleted"; exit 1; }
done

echo "✅ The binaries that do not match the reference were deleted"
exit 0
