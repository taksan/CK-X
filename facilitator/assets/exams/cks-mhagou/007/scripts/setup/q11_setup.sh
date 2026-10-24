#!/bin/bash

# Setup for MHAGOU-007 Question 11: binaries and a SHA-512 reference file (files on the jumphost).
# bin/ has four files named like Kubernetes components (content: small real executables). The reference
# file (sha512sum format) has the hash of the original of each one; two of them, chosen at random, are
# tampered with after the reference was written. The names of the tampered files are in .tampered.

source "$(dirname "$0")/../lib/wait-cluster.sh"

DIR="/tmp/exam/mhagou-007-q11"
mkdir -p "${DIR:?}/bin"
rm -f "${DIR:?}"/bin/* "${DIR:?}"/reference.sha512 "${DIR:?}"/.tampered

cp /usr/bin/true "$DIR/bin/kubelet"
cp /usr/bin/cat "$DIR/bin/kube-proxy"
cp /usr/bin/wc "$DIR/bin/kubeadm"
cp /usr/bin/ls "$DIR/bin/kubectl"
(cd "$DIR" && sha512sum bin/kubelet bin/kube-proxy bin/kubeadm bin/kubectl > reference.sha512)

for n in $(printf '%s\n' kubelet kube-proxy kubeadm kubectl | shuf -n 2); do
  printf 'injected\n' >> "$DIR/bin/$n"
  echo "$n" >> "$DIR/.tampered"
done

echo "Setup completed for MHAGOU-007 Question 11 (files in $DIR)"
exit 0
