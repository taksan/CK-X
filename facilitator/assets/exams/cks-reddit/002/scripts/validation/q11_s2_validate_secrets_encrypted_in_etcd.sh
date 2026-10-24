#!/bin/bash
# Validate by behaviour that Secrets are really stored encrypted in etcd:
# create a Secret and read its raw value from etcd (it must start with k8s:enc:aescbc).

NODE="${Q11_NODE:-k8s-api-server}"
NAMESPACE="encryption"   # namespace used only by this check
kubectl create namespace "$NAMESPACE" >/dev/null 2>&1
ID="ckx-enc-$RANDOM$RANDOM"

CMD=$(kubectl get pods -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null || true)
if ! echo "$CMD" | grep -q -- '--encryption-provider-config='; then
  echo "❌ kube-apiserver is not configured with --encryption-provider-config"
  exit 1
fi

kubectl create secret generic "$ID" -n "$NAMESPACE" --from-literal=probe=plaintext-marker >/dev/null 2>&1
sleep 1

RAW=$(ssh -o StrictHostKeyChecking=no "$NODE" "
  export CONTAINER_RUNTIME_ENDPOINT=unix:///run/containerd/containerd.sock
  E=\$(crictl ps --name etcd -q 2>/dev/null | head -1)
  crictl exec \$E etcdctl --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key \
    get /registry/secrets/$NAMESPACE/$ID --print-value-only 2>/dev/null | head -c 4000" 2>/dev/null | tr -d '\000' )

kubectl delete secret "$ID" -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1

if [ -z "$RAW" ]; then
  echo "❌ Could not read the test Secret from etcd"
  exit 1
fi

if echo "$RAW" | grep -aq 'plaintext-marker'; then
  echo "❌ Secrets are stored in plain text in etcd (check the order of the providers)"
  exit 1
fi

if ! echo "$RAW" | grep -aq 'k8s:enc:aescbc:v1:'; then
  echo "❌ The Secret is not stored with the aescbc provider in etcd"
  exit 1
fi

echo "✅ Secrets are stored encrypted (aescbc) in etcd"
exit 0
