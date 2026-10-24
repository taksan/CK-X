#!/bin/bash
# Item (by behaviour): a NEW Secret is stored encrypted in etcd: create a probe Secret and read its raw value
# from etcd (it must start with k8s:enc:aescbc:v1: and not contain the plain text)

source "$(dirname "$0")/../lib/apiserver.sh"
NS="enc-probe"

[ -n "$(apiserver_flag encryption-provider-config)" ] || { echo "❌ kube-apiserver has no --encryption-provider-config flag"; exit 1; }
wait_api_ready 150 || { echo "❌ The API server is not ready"; exit 1; }

ID="ckx-enc-$RANDOM$RANDOM"
kubectl create secret generic "$ID" -n "$NS" --from-literal=probe=plaintext-marker >/dev/null 2>&1 || { echo "❌ Unable to create the probe Secret in $NS"; exit 1; }

RAW=""
for i in 1 2 3; do
  RAW=$(ssh -o StrictHostKeyChecking=no "$APISERVER_NODE" "
    export CONTAINER_RUNTIME_ENDPOINT=unix:///run/containerd/containerd.sock
    E=\$(crictl ps --name etcd -q 2>/dev/null | head -1)
    crictl exec \$E etcdctl --endpoints=https://127.0.0.1:2379 \
      --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key \
      get /registry/secrets/$NS/$ID --print-value-only 2>/dev/null | head -c 4000" 2>/dev/null | tr -d '\000')
  [ -n "$RAW" ] && break
  sleep 2
done
kubectl delete secret "$ID" -n "$NS" --ignore-not-found >/dev/null 2>&1

[ -n "$RAW" ] || { echo "❌ Could not read the probe Secret from etcd"; exit 1; }
if echo "$RAW" | grep -aq 'plaintext-marker'; then
  echo "❌ New Secrets are stored in plain text in etcd (check the provider order and that the API server uses the configuration)"
  exit 1
fi
echo "$RAW" | grep -aq 'k8s:enc:aescbc:v1:' || { echo "❌ The Secret is not stored with the aescbc provider in etcd"; exit 1; }

echo "✅ New Secrets are stored encrypted with aescbc in etcd"
exit 0
