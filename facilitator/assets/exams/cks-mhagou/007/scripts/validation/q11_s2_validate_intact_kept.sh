#!/bin/bash
# Item: the binaries that match are kept untouched (credited once the mismatching ones are deleted)

DIR="${Q11_DIR:-/tmp/exam/mhagou-007-q11}"
[ -f "$DIR/.tampered" ] || { echo "❌ Internal state file missing"; exit 1; }
for n in $(cat "$DIR/.tampered"); do
  [ ! -e "$DIR/bin/$n" ] || { echo "❌ The mismatching binaries are not deleted yet, nothing to credit"; exit 1; }
done

for n in kubelet kube-proxy kubeadm kubectl; do
  grep -qx "$n" "$DIR/.tampered" && continue
  [ -f "$DIR/bin/$n" ] || { echo "❌ $n matches its checksum and must not be deleted"; exit 1; }
  WANT=$(awk -v f="bin/$n" '$2 == f {print $1}' "$DIR/reference.sha512")
  [ "$(sha512sum "$DIR/bin/$n" | awk '{print $1}')" = "$WANT" ] || { echo "❌ $n was modified"; exit 1; }
done

echo "✅ The binaries that match the reference were kept"
exit 0
