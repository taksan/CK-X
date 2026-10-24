#!/bin/bash

# Setup for CKS-004 Question 15: binary integrity. Files only (jumphost).
# Four files with fixed content (the expected sha512 values are in the file checksums.sha512 next to the directory); two of them,
# chosen at random on every run, are tampered with. The tampered ones are recorded in a state file
# outside the binaries directory.

source "$(dirname "$0")/../lib/wait-cluster.sh"

DIR="/tmp/exam/cks-004-q15"
BIN="$DIR/binaries"
mkdir -p "${BIN:?}"
rm -f "${BIN:?}"/* "${DIR:?}"/.tampered

# the verified checksums of the four files (sha512sum -c format), next to the directory
cat > "$DIR/checksums.sha512" <<'SUMS'
65332f62829c22c4056c9c32a32eff4bf4a8fe1e827c20dc07ac30a2f055a814a5044984ef142810f4015b4e4e7c45e9378e36eafa80cbc4dd14bf29c948d66b  kube-apiserver
23fad8e06017c64841136c4d26fd2aac3bea60f9068753b6978f3e58f92d164fcd745c7432d6bd42b4b6d9caad3586da18d3e70a8074442573918b184d94e4e6  kube-controller-manager
a731b48e0451c3ff82bcf547703b1b658ac1e60080f0bd89bae067859155d00f8e61c18c5c2a8d630e8e6ae237a32b8e47c789b1c21350b6ee71744459c37ccb  kube-proxy
12ae47581fe425512f7c82ab2baf9771237dba3dadbb9562677d41c66880c6e6fe5ca6c5a55ae33c8db28c6576ce5e4652cbb64d09366702ace6c8492badb9f9  kubelet
SUMS

NAMES="kube-apiserver kube-controller-manager kube-proxy kubelet"
for n in $NAMES; do
  printf 'ckx-004-release-binary:%s:v1\n' "$n" > "$BIN/$n"
  chmod +x "$BIN/$n"
done

for n in $(echo $NAMES | tr ' ' '\n' | shuf -n 2); do
  printf 'injected-payload\n' >> "$BIN/$n"
  echo "$n" >> "$DIR/.tampered"
done

echo "Setup completed for CKS-004 Question 15 (binaries in $BIN)"
exit 0
