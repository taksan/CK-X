#!/bin/bash
# kube-apiserver cipher suites contain exactly TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 (manifest and running process)

source "$(dirname "$0")/../lib/tls-q12.sh"
M=$(manifest_cmd kube-apiserver)
[ -n "$M" ] || { echo "❌ Unable to read the kube-apiserver manifest on the control plane"; exit 1; }
V=$(echo "$M" | jq -r '[.[] | select(startswith("--tls-cipher-suites="))] | first // empty | sub("^--tls-cipher-suites="; "")')
[ -n "$V" ] || { echo "❌ kube-apiserver has no --tls-cipher-suites flag"; exit 1; }
[ "$V" = "$CIPHER" ] || { echo "❌ --tls-cipher-suites of kube-apiserver is '$V', expected exactly $CIPHER"; exit 1; }
running_cmd kube-apiserver | grep -q -- "--tls-cipher-suites=$CIPHER\( \|$\)" || { echo "❌ The running kube-apiserver process does not use --tls-cipher-suites=$CIPHER (was it restarted?)"; exit 1; }

echo "✅ kube-apiserver cipher suites: exactly $CIPHER"
exit 0
