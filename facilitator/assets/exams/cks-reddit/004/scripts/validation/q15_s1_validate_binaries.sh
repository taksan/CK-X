#!/bin/bash
# Validate: tampered binaries removed, intact binaries untouched

DIR="${Q15_DIR:-/tmp/exam/cks-004-q15}"
BIN="$DIR/binaries"
[ -f "$DIR/.tampered" ] || { echo "❌ Internal state file missing"; exit 1; }

for n in kube-apiserver kube-controller-manager kube-proxy kubelet; do
  EXPECTED=$(printf 'ckx-004-release-binary:%s:v1\n' "$n" | sha512sum | awk '{print $1}')
  if grep -qx "$n" "$DIR/.tampered"; then
    [ ! -e "$BIN/$n" ] || { echo "❌ $n does not match its checksum and must be deleted"; exit 1; }
  else
    [ -f "$BIN/$n" ] || { echo "❌ $n matches its checksum and must not be deleted"; exit 1; }
    [ "$(sha512sum "$BIN/$n" | awk '{print $1}')" = "$EXPECTED" ] || { echo "❌ $n was modified"; exit 1; }
  fi
done

echo "✅ Tampered binaries removed, intact binaries kept"
exit 0
