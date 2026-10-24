#!/bin/bash

# Session cleanup for MHAGOU-007, run on the jumphost at exam termination by
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
# Q8: the admission policy must go first, it would reject the namespaces named lab-*
kubectl delete validatingadmissionpolicybinding require-env-label-binding --ignore-not-found >/dev/null 2>&1
kubectl delete validatingadmissionpolicy require-env-label --ignore-not-found >/dev/null 2>&1
EXAM_NAMESPACES="exposure-lab dev-z sbom-lab rocket devmem-lab data-tier web-tier outside-lab dev-clients"
# namespaces that the candidate created to test the policy of Q8 (their names start with lab-)
LAB_NAMESPACES=$(kubectl get namespaces -o name 2>/dev/null | sed 's#namespace/##' | grep '^lab-' | tr '\n' ' ')
for ns in $EXAM_NAMESPACES; do
  kubectl delete pods --all -n "$ns" --force --grace-period=0 >/dev/null 2>&1
done
kubectl delete namespace $EXAM_NAMESPACES $LAB_NAMESPACES --ignore-not-found --wait=false >/dev/null 2>&1
# Q10: cluster-wide Cilium policies that the candidate may have created
kubectl delete ciliumclusterwidenetworkpolicies --all >/dev/null 2>&1

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

log "MHAGOU-007 session cleanup completed"
exit 0
