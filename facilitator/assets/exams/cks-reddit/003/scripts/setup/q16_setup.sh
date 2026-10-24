#!/bin/bash

# Setup for CKS-003 Question 16: verify downloaded binaries against an official checksum.
#
# Two copies of the kubectl binary are provided; one of them is tampered (which one is
# random on every run). checksums.txt holds the official SHA-256 of the genuine binary.

WORKDIR="/tmp/exam/cks-003-q16"
STATE="/tmp/exam/.cks-003-q16.state"
KUBECTL=$(command -v kubectl)

mkdir -p "${WORKDIR:?}"
rm -f "${WORKDIR:?}"/*
rm -f "${STATE:?}"

cp "$KUBECTL" "$WORKDIR/kubectl-a"
cp "$KUBECTL" "$WORKDIR/kubectl-b"
SHA=$(sha256sum "$KUBECTL" | awk '{print $1}')

if [ $((RANDOM % 2)) -eq 0 ]; then TAMPERED="kubectl-a"; GENUINE="kubectl-b"; else TAMPERED="kubectl-b"; GENUINE="kubectl-a"; fi
printf '\0' >> "$WORKDIR/$TAMPERED"

echo "$SHA  kubectl" > "$WORKDIR/checksums.txt"
printf '%s %s %s\n' "$TAMPERED" "$GENUINE" "$SHA" > "$STATE"

echo "Setup completed for CKS-003 Question 16 (files in $WORKDIR)"
exit 0
