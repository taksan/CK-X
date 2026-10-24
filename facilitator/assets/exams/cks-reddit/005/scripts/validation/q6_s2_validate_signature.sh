#!/bin/bash
# Validate: internal-tools:1.0 has a signature that verifies with the candidate's public key and
# internal-tools:1.1 is NOT signed with it

DIR="${Q6_DIR:-/tmp/exam/cks-005-q6}"
REGISTRY=$(cat "$DIR/registry.txt" 2>/dev/null)
[ -n "$REGISTRY" ] && [ -s "$DIR/cosign.pub" ] || { echo "❌ Missing registry.txt or cosign.pub"; exit 1; }

verify() { cosign verify --key "$DIR/cosign.pub" --insecure-ignore-tlog=true "$REGISTRY/internal-tools:$1" >/dev/null 2>&1; }

verify 1.0 || { echo "❌ internal-tools:1.0 has no signature that verifies with $DIR/cosign.pub"; exit 1; }
verify 1.1 && { echo "❌ internal-tools:1.1 is signed too: only 1.0 had to be signed"; exit 1; }

echo "✅ internal-tools:1.0 is signed with the generated key; 1.1 is not"
exit 0
