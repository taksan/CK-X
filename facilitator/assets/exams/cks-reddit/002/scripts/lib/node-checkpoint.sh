#!/bin/bash

# Checkpoint / restore of the node files that the CKS-002 questions change.
#
# Usage: node-checkpoint.sh create|restore|status
#
# The files are tracked in a git repository whose git dir lives outside the
# tracked tree (/root/.ckx-checkpoint.git, work tree /). Only an explicit list of
# paths is tracked, so live data such as /var/lib/kubelet/pods is never touched.
#
#  - the first "restore" (or "create") takes the checkpoint of the current,
#    pristine state; later runs put the files back to exactly that state
#  - to take a new checkpoint, remove /root/.ckx-checkpoint.git on the nodes
#
# Nodes can be overridden with CKX_NODES (ssh aliases).

set -uo pipefail

ACTION="${1:-restore}"
NODES="${CKX_NODES:-k8s-api-server node01 node02}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [node-checkpoint] $*"; }

FAILED=0
for node in $NODES; do
  log "$ACTION on $node"
  if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "$node" 'bash -s' -- "$ACTION" <<'REMOTE'
set -euo pipefail
ACTION="$1"
export GIT_DIR=/root/.ckx-checkpoint.git GIT_WORK_TREE=/
cd /

PATHS=(etc/kubernetes etc/apparmor.d etc/audit var/lib/kubelet/config.yaml var/lib/kubelet/kubeadm-flags.env)
CLEAN_DIRS=(etc/kubernetes etc/apparmor.d etc/audit)

create() {
  # /etc/audit is tracked (through a placeholder) so that files created there are cleaned
  mkdir -p /etc/audit
  touch /etc/audit/.keep
  git init -q
  git config user.name ckx-checkpoint
  git config user.email ckx-checkpoint@example.invalid
  git add -f -- "${PATHS[@]}"
  git commit -q -m "CK-X checkpoint"
  echo "checkpoint created"
}

restore() {
  # unload AppArmor profiles that were loaded from files added after the checkpoint
  git ls-files --others -- etc/apparmor.d | while read -r f; do
    apparmor_parser -R "/$f" >/dev/null 2>&1 || true
  done

  KUBELET_CHANGED=$(git status --porcelain -- var/lib/kubelet/config.yaml var/lib/kubelet/kubeadm-flags.env | wc -l)

  git checkout -q HEAD -- "${PATHS[@]}"
  git clean -qfdx -- "${CLEAN_DIRS[@]}"
  rm -f /var/log/kubernetes-logs.log*

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

  if [ "$KUBELET_CHANGED" -ne 0 ]; then
    systemctl restart kubelet
  fi
  echo "restored (kubelet restarted: $([ "$KUBELET_CHANGED" -ne 0 ] && echo yes || echo no))"
}

case "$ACTION" in
  create)  [ -d "$GIT_DIR" ] && { echo "checkpoint already exists"; exit 0; }; create ;;
  restore) [ -d "$GIT_DIR" ] || { create; exit 0; }; restore ;;
  status)  [ -d "$GIT_DIR" ] || { echo "no checkpoint"; exit 0; }; git status --short -- "${PATHS[@]}" ;;
  *) echo "unknown action $ACTION" >&2; exit 1 ;;
esac
REMOTE
  then
    log "FAILED on $node"
    FAILED=$((FAILED + 1))
  fi
done

[ "$FAILED" -eq 0 ] || exit 1
exit 0
