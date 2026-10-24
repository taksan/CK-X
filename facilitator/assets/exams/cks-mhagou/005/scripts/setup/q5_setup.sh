#!/bin/bash

# Setup for MHagou-005 Question 5: SHA-256 checksums of kubectl and kubelet on the control plane
# (k8s-api-server). The candidate writes /tmp/exam/mhagou-005-q5/verified-hashes.txt on that node
# (the node restore wipes /tmp/exam). The checksums at the start are kept in a hidden file so that
# the validators can see whether a binary was replaced.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

ssh -o StrictHostKeyChecking=no k8s-api-server 'bash -s' <<'EOF' || { echo "WARNING: unable to prepare $CONTROL_PLANE"; exit 1; }
set -e
DIR=/tmp/exam/mhagou-005-q5
mkdir -p "$DIR"
rm -f "$DIR"/verified-hashes.txt "$DIR"/.expected
for b in kubectl kubelet; do
  p=$(command -v "$b")
  test -f "$p" && test -x "$p"
  echo "$b $p $(sha256sum "$p" | cut -d' ' -f1)" >> "$DIR/.expected"
done
EOF

echo "Setup completed for MHagou-005 Question 5 (output on $CONTROL_PLANE: /tmp/exam/mhagou-005-q5)"
exit 0
