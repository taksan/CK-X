#!/bin/bash

# Checkpoint / restore of the node files that the MHagou-004 questions change.
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

PATHS=(etc/kubernetes etc/apparmor.d etc/audit etc/falco var/lib/kubelet/config.yaml var/lib/kubelet/kubeadm-flags.env)
CLEAN_DIRS=(etc/kubernetes etc/apparmor.d etc/audit etc/falco)

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

extend() {
  # A checkpoint taken by an older exam may not track every path of this one. Paths that
  # no question of an exam changes are still pristine, so they can be added to it.
  local added=0 p
  for p in "${PATHS[@]}"; do
    if [ -z "$(git ls-files -- "$p" | head -1)" ] && [ -e "/$p" ]; then
      git add -f -- "$p"; added=1
    fi
  done
  [ "$added" -eq 0 ] || git commit -q -m "CK-X checkpoint: extend tracked paths"
}

restore() {
  extend
  # unload AppArmor profiles that were loaded from files added after the checkpoint
  git ls-files --others -- etc/apparmor.d | while read -r f; do
    apparmor_parser -R "/$f" >/dev/null 2>&1 || true
  done

  KUBELET_CHANGED=$(git status --porcelain -- var/lib/kubelet/config.yaml var/lib/kubelet/kubeadm-flags.env | wc -l)
  FALCO_CHANGED=$(git status --porcelain -- etc/falco | wc -l)

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

  # leftovers of the questions outside the tracked paths (a fake LDAP service, exam files)
  # falco instances started by hand (the falco service itself keeps running)
  MAIN=$(systemctl show -p MainPID --value falco-modern-bpf 2>/dev/null)
  for p in $(pgrep -x falco 2>/dev/null); do
    [ "$p" = "$MAIN" ] || kill "$p" 2>/dev/null || true
  done
  pkill -x ldapd 2>/dev/null || true
  rm -f /usr/local/sbin/ldapd /var/log/ldapd.log
  rm -rf /var/lib/kubelet/seccomp
  # simulated suspicious host process of an exam question and the firewall rule the candidate added
  if [ -f /var/tmp/.ckx-q8-state ]; then
    . /var/tmp/.ckx-q8-state
    for chain in OUTPUT FORWARD INPUT; do
      while iptables -S "$chain" 2>/dev/null | grep -q -- "-d ${Q8_IP}/32"; do
        RULE=$(iptables -S "$chain" | grep -- "-d ${Q8_IP}/32" | head -1 | sed "s/^-A /-D /")
        iptables $RULE 2>/dev/null || break
      done
    done
  fi
  pkill -f '/var/tmp/\.ckx-' 2>/dev/null || true
  rm -rf /var/tmp/.ckx-*
  rm -rf /tmp/exam

  # Falco: a candidate can break it (an invalid rule file makes it crash-loop or stop), so the enabled
  # service is brought back whatever its state when the files changed or it is not running
  for u in falco-modern-bpf falco-kmod falco-custom; do
    if systemctl is-enabled --quiet "$u" 2>/dev/null; then
      if [ "$FALCO_CHANGED" -ne 0 ] || ! systemctl is-active --quiet "$u" 2>/dev/null; then
        systemctl reset-failed "$u" >/dev/null 2>&1 || true
        systemctl restart "$u" || true
      fi
    fi
  done

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
