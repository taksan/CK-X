#!/bin/bash
# Behaviour: the kube-apiserver rejects a TLS 1.2 handshake (and still accepts TLS 1.3)

source "$(dirname "$0")/../lib/tls-q12.sh"
OK=1
for i in $(seq 1 15); do tls_accepts tls1_3 && { OK=0; break; }; sleep 3; done
[ "$OK" -eq 0 ] || { echo "❌ The kube-apiserver does not answer a TLS 1.3 handshake (is it healthy?)"; exit 1; }

if tls_accepts tls1_2; then
  echo "❌ The kube-apiserver still accepts TLS 1.2"
  exit 1
fi

echo "✅ The kube-apiserver rejects TLS 1.2"
exit 0
