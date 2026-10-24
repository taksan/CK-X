#!/bin/bash
# Source this file: sets NODE01, NODE02 and CONTROL_PLANE, the names that THIS cluster gives to the first and the
# second worker node and to the control plane. The exams must not hard-code node names (the cluster of the user can
# name its nodes as it likes): use $NODE01 / $NODE02 / $CONTROL_PLANE wherever a Kubernetes node name is needed
# (nodeName, kubernetes.io/hostname, kubectl get/label/drain node ...). The ssh aliases k8s-api-server, node01 and
# node02 keep working, they are written for every cluster; so does the real node name.
#
# The jumphost determines them when the exam is prepared (ckx-node-vars --write); outside of the jumphost
# (a test session on the host) set NODE01/NODE02/CONTROL_PLANE or let the defaults of the lab cluster apply.

if [ -z "${NODE01:-}" ] || [ -z "${NODE02:-}" ] || [ -z "${CONTROL_PLANE:-}" ]; then
  if [ -r /home/candidate/.kube/ckx-vars.env ]; then
    . /home/candidate/.kube/ckx-vars.env
  elif command -v ckx-node-vars >/dev/null 2>&1; then
    eval "$(ckx-node-vars --env 2>/dev/null)"
  elif [ -n "${CKX_REPO:-}" ] && [ -x "$CKX_REPO/jumphost/scripts/ckx-node-vars.sh" ]; then
    eval "$("$CKX_REPO/jumphost/scripts/ckx-node-vars.sh" --env 2>/dev/null)"
  fi
fi
: "${NODE01:=node01}"; : "${NODE02:=node02}"; : "${CONTROL_PLANE:=k8s-api-server}"
export NODE01 NODE02 CONTROL_PLANE
