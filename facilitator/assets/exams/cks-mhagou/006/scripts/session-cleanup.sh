#!/bin/bash

# Session cleanup for MHagou-006, run on the jumphost at exam termination by
# cleanup-exam-env (from /tmp/exam-assets/scripts/session-cleanup.sh).
#
# The cluster is an external, persistent one, so everything the exam created is
# removed here and the nodes are restored to the checkpoint.

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [session-cleanup] $*"; }

export KUBECONFIG="${KUBECONFIG:-/home/candidate/.kube/kubeconfig}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! ssh -o BatchMode=yes -o ConnectTimeout=10 k8s-api-server 'test -d /etc/kubernetes/manifests' >/dev/null 2>&1; then
  log "No kubeadm control plane reachable over ssh: nothing to clean"
  exit 0
fi

log "Restoring the nodes to the checkpoint"
"$HERE/lib/node-checkpoint.sh" restore || log "node restore reported errors"

log "Waiting for the API server"
for i in $(seq 1 90); do
  kubectl get --raw /readyz >/dev/null 2>&1 && break
  sleep 5
done

log "Deleting the resources created by the exam"
EXAM_NAMESPACES="mem-watch asia europe world nginx-watch sandbox-lab staff-lab kernel-lab pss-test app data manage inspect-lab gvisor-lab"
for ns in $EXAM_NAMESPACES; do
  kubectl delete pods --all -n "$ns" --force --grace-period=0 >/dev/null 2>&1
done
kubectl delete namespace $EXAM_NAMESPACES --ignore-not-found --wait=false >/dev/null 2>&1
kubectl delete runtimeclass not-trusted hardened --ignore-not-found >/dev/null 2>&1
# CertificateSigningRequests created for the user 60099@internal.users
for csr in $(kubectl get csr -o name 2>/dev/null); do
  if kubectl get "$csr" -o jsonpath='{.spec.request}' 2>/dev/null | base64 -d 2>/dev/null \
       | openssl req -noout -subject 2>/dev/null | grep -Eq '60099@internal.users'; then
    kubectl delete "$csr" --ignore-not-found >/dev/null 2>&1
  fi
done
# kubeconfig users/contexts of that user (the candidate adds them to the kubeconfig of the jumphost)
CFG=$(kubectl config view --raw -o json 2>/dev/null)
for u in $(echo "$CFG" | jq -r '.users[]? | select(.user["client-certificate-data"] != null) | "\(.name)|\(.user["client-certificate-data"])"' 2>/dev/null); do
  name="${u%%|*}"; data="${u#*|}"
  if echo "$data" | base64 -d 2>/dev/null | openssl x509 -noout -subject 2>/dev/null | grep -q '60099@internal.users'; then
    for c in $(echo "$CFG" | jq -r --arg n "$name" '.contexts[]? | select(.context.user == $n) | .name'); do
      kubectl config delete-context "$c" >/dev/null 2>&1
    done
    kubectl config unset "users.$name" >/dev/null 2>&1
  fi
done

# default namespace: no question uses it; this only removes what a candidate may have created there by accident
kubectl delete pods,deployments,statefulsets,daemonsets,jobs,cronjobs,networkpolicies,ingresses \
  --all -n default --wait=false >/dev/null 2>&1
kubectl delete services --field-selector metadata.name!=kubernetes -n default >/dev/null 2>&1
kubectl delete secrets --all -n default >/dev/null 2>&1
kubectl delete configmaps --field-selector metadata.name!=kube-root-ca.crt -n default >/dev/null 2>&1
kubectl delete serviceaccounts --field-selector metadata.name!=default -n default >/dev/null 2>&1

log "Waiting for the exam namespaces to be removed"
for i in $(seq 1 60); do
  [ -z "$(kubectl get namespace $EXAM_NAMESPACES --ignore-not-found --no-headers 2>/dev/null)" ] && break
  sleep 3
done

log "MHagou-006 session cleanup completed"
exit 0
