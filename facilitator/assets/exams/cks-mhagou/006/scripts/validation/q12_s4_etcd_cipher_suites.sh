#!/bin/bash
# etcd client TLS cipher suites contain exactly TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 (manifest and running process)

source "$(dirname "$0")/../lib/tls-q12.sh"
M=$(manifest_cmd etcd)
[ -n "$M" ] || { echo "❌ Unable to read the etcd manifest on the control plane"; exit 1; }
V=$(echo "$M" | jq -r '[.[] | select(startswith("--cipher-suites="))] | first // empty | sub("^--cipher-suites="; "")')
[ -n "$V" ] || { echo "❌ etcd has no --cipher-suites flag"; exit 1; }
[ "$V" = "$CIPHER" ] || { echo "❌ --cipher-suites of etcd is '$V', expected exactly $CIPHER"; exit 1; }
running_cmd etcd | grep -q -- "--cipher-suites=$CIPHER\( \|$\)" || { echo "❌ The running etcd process does not use --cipher-suites=$CIPHER (was it restarted?)"; exit 1; }

echo "✅ etcd cipher suites: exactly $CIPHER"
exit 0
