#!/bin/bash

# settings of an external cluster whose ingress/nodes need special care (written by a lane script)
[ -f /home/candidate/.ssh/ckx-lane.env ] && . /home/candidate/.ssh/ckx-lane.env

# Source this file and call wait_cluster_ready after anything that restarts the
# control plane. Besides /readyz and the nodes, it waits until the controllers
# have caught up (a new namespace gets its default ServiceAccount), otherwise
# the Pods created right after a restart are rejected.

wait_cluster_ready() {
  local timeout_steps="${1:-90}" i probe

  for i in $(seq 1 "$timeout_steps"); do
    if kubectl get --raw /readyz >/dev/null 2>&1 \
       && [ -z "$(kubectl get nodes --no-headers 2>/dev/null | awk -v skip=" ${CKX_IGNORE_NODES:-} " 'index(skip, " " $1 " ") == 0 && $2 != "Ready"')" ] \
       && [ -z "$(kubectl get pods -n kube-system -l 'component in (kube-apiserver,etcd,kube-controller-manager,kube-scheduler)' --no-headers 2>/dev/null | awk '$2 !~ /^1\/1$/')" ]; then
      break
    fi
    sleep 5
  done

  probe="ckx-probe-$RANDOM"
  kubectl create namespace "$probe" >/dev/null 2>&1 || true
  for i in $(seq 1 60); do
    kubectl get serviceaccount default -n "$probe" >/dev/null 2>&1 && break
    sleep 3
  done
  kubectl delete namespace "$probe" --wait=false >/dev/null 2>&1 || true
}

# Create a namespace (if needed) and wait for its default ServiceAccount, so that
# Pods created right afterwards are not rejected.
ensure_namespace() {
  local ns="$1" i
  # a namespace left over from a previous session may still be terminating
  for i in $(seq 1 90); do
    kubectl get namespace "$ns" >/dev/null 2>&1 || break
    [ -n "$(kubectl get namespace "$ns" -o jsonpath='{.metadata.deletionTimestamp}' 2>/dev/null)" ] || break
    sleep 2
  done
  kubectl create namespace "$ns" >/dev/null 2>&1 || true
  for i in $(seq 1 60); do
    kubectl get serviceaccount default -n "$ns" >/dev/null 2>&1 && return 0
    sleep 2
  done
  echo "Timed out waiting for the default ServiceAccount in namespace '$ns'" >&2
  return 1
}
