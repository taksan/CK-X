#!/bin/bash
# After the changes the running processes carry the new settings, exactly one kube-apiserver and one
# etcd process run and the API server is Ready including its etcd check

source "$(dirname "$0")/../lib/tls-q12.sh"
running_cmd kube-apiserver | grep -q -- '--tls-min-version=VersionTLS13' || { echo "❌ The running kube-apiserver does not carry the TLS settings yet"; exit 1; }
running_cmd etcd | grep -q -- "--cipher-suites=$CIPHER" || { echo "❌ The running etcd does not carry the cipher suites yet"; exit 1; }

NA=$(ssh -o StrictHostKeyChecking=no "$CP" "pgrep -x kube-apiserver | wc -l" 2>/dev/null)
NE=$(ssh -o StrictHostKeyChecking=no "$CP" "pgrep -x etcd | wc -l" 2>/dev/null)
[ "$NA" = "1" ] || { echo "❌ $NA kube-apiserver processes run on the control plane, expected exactly one"; exit 1; }
[ "$NE" = "1" ] || { echo "❌ $NE etcd processes run on the control plane, expected exactly one"; exit 1; }

R=""
for i in $(seq 1 30); do
  R=$(kubectl get --raw '/readyz?verbose' 2>/dev/null)
  echo "$R" | grep -q '\[+\]etcd ok' && echo "$R" | grep -q '^readyz check passed' && break
  R=""; sleep 3
done
[ -n "$R" ] || { echo "❌ The API server is not Ready with its etcd check passing"; exit 1; }

echo "✅ One kube-apiserver and one etcd process run, and the API server is Ready including etcd"
exit 0
