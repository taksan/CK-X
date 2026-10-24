#!/bin/bash

# Setup for CKS-005 Question 6: sign an image with cosign. Files on the jumphost plus the lab
# registry (repository "internal-tools", tags 1.0 and 1.1; only 1.0 has to be signed).

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/registry.sh"

WORKDIR="/tmp/exam/cks-005-q6"
mkdir -p "${WORKDIR:?}"
rm -rf "${WORKDIR:?}"/*

ensure_registry || { echo "WARNING: the lab registry is not reachable"; exit 1; }
cosign copy --platform linux/amd64 busybox:1.36.1 "$REGISTRY/internal-tools:1.0" >/dev/null 2>&1 || { echo "WARNING: unable to copy the image"; exit 1; }
cosign copy --platform linux/amd64 busybox:1.35.0 "$REGISTRY/internal-tools:1.1" >/dev/null 2>&1 || { echo "WARNING: unable to copy the image"; exit 1; }

echo "$REGISTRY" > "$WORKDIR/registry.txt"
echo "Setup completed for CKS-005 Question 6 (registry $REGISTRY, directory $WORKDIR)"
exit 0
