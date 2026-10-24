#!/bin/bash
# Deletes the Secrets that a candidate left encrypted in etcd (aescbc) on the kubeadm control plane.
#
# Once the kube-apiserver loses the encryption key (another exam restores its manifest) it cannot read them and never
# becomes ready. Their content could not be read anyway. Skipped on clusters without a kubeadm control plane (k3d).

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [encrypted-secrets] $*"; }

if ! ssh -o BatchMode=yes -o ConnectTimeout=10 k8s-api-server 'test -f /etc/kubernetes/manifests/etcd.yaml' >/dev/null 2>&1; then
  log "No kubeadm control plane reachable over ssh: nothing to clean"
  exit 0
fi

ssh -o BatchMode=yes -o ConnectTimeout=10 k8s-api-server 'bash -s' <<'REMOTE'
set -uo pipefail
# Secrets the candidate left encrypted in etcd (aescbc): the restored kube-apiserver has no key any more, cannot
# read them and never becomes ready, so they are deleted (their content could not be read anyway)
if [ -f /etc/kubernetes/manifests/etcd.yaml ]; then
  ETCD_ID=$(crictl ps -q --name '^etcd$' 2>/dev/null | head -1 || true)
  if [ -n "$ETCD_ID" ]; then
    ETCDCTL=(crictl exec "$ETCD_ID" etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key)
    for secret_key in $("${ETCDCTL[@]}" get /registry/secrets --prefix --keys-only 2>/dev/null | grep '^/registry/' || true); do
      value_start=$("${ETCDCTL[@]}" get "$secret_key" --print-value-only 2>/dev/null | head -c 16 | tr -d '\0' || true)
      if [[ "$value_start" == *k8s:enc:* ]]; then
        "${ETCDCTL[@]}" del "$secret_key" >/dev/null && echo "deleted the Secret $secret_key (left encrypted in etcd)"
      fi
    done
  fi
fi
REMOTE
