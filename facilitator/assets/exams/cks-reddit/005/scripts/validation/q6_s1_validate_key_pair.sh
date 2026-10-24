#!/bin/bash
# Validate the cosign key pair in the working directory

DIR="${Q6_DIR:-/tmp/exam/cks-005-q6}"
[ -s "$DIR/cosign.key" ] || { echo "❌ $DIR/cosign.key does not exist"; exit 1; }
[ -s "$DIR/cosign.pub" ] || { echo "❌ $DIR/cosign.pub does not exist"; exit 1; }
grep -q 'ENCRYPTED SIGSTORE PRIVATE KEY' "$DIR/cosign.key" || { echo "❌ cosign.key is not a cosign private key"; exit 1; }
openssl pkey -pubin -in "$DIR/cosign.pub" -noout >/dev/null 2>&1 || { echo "❌ cosign.pub is not a valid public key"; exit 1; }

echo "✅ cosign.key and cosign.pub exist and are valid"
exit 0
