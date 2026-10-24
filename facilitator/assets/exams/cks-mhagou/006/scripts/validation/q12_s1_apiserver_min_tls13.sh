#!/bin/bash
# kube-apiserver requires TLS 1.3 as its minimum: the manifest flag, the running process and a real TLS 1.3 handshake

source "$(dirname "$0")/../lib/tls-q12.sh"
M=$(manifest_cmd kube-apiserver)
[ -n "$M" ] || { echo "❌ Unable to read the kube-apiserver manifest on the control plane"; exit 1; }
echo "$M" | jq -e 'index("--tls-min-version=VersionTLS13") != null' >/dev/null || { echo "❌ kube-apiserver is not configured with --tls-min-version=VersionTLS13"; exit 1; }

running_cmd kube-apiserver | grep -q -- '--tls-min-version=VersionTLS13' || { echo "❌ The running kube-apiserver process does not use --tls-min-version=VersionTLS13 (was it restarted?)"; exit 1; }

OK=1
for i in $(seq 1 15); do tls_accepts tls1_3 && { OK=0; break; }; sleep 3; done
[ "$OK" -eq 0 ] || { echo "❌ The kube-apiserver does not negotiate TLS 1.3"; exit 1; }

echo "✅ kube-apiserver requires TLS 1.3 as its minimum and negotiates it"
exit 0
