#!/bin/bash
# Integration test of ckx-cluster-labels on a THROWAWAY kind cluster (created and deleted here).
# It never touches another cluster: it uses its own kubeconfig file and stops unless the context is kind-*.
#
#   jumphost/tests/test-cluster-labels-kind.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$HERE/../scripts/ckx-cluster-labels.py"
NAME=ckx-labels-test
WORK="$(mktemp -d)"
export KUBECONFIG="$WORK/kubeconfig"
FAILED=0

cleanup() { kind delete cluster --name "$NAME" --kubeconfig "$KUBECONFIG" >/dev/null 2>&1; rm -rf "$WORK"; }
trap cleanup EXIT

check() { # description, command...
  local what=$1; shift
  if "$@" >/dev/null 2>&1; then echo "ok   - $what"; else echo "FAIL - $what"; FAILED=1; fi
}
tool() { python3 -I "$TOOL" "$@"; }
exists() { kubectl get "$@" >/dev/null 2>&1; }

kind delete cluster --name "$NAME" --kubeconfig "$KUBECONFIG" >/dev/null 2>&1
kind create cluster --name "$NAME" --kubeconfig "$KUBECONFIG" --wait 120s >/dev/null || { echo "cannot create the kind cluster"; exit 1; }
[ "$(kubectl config current-context)" = "kind-$NAME" ] || { echo "ABORT: the context is not kind-$NAME"; exit 1; }

# the platform: what the cluster runs, created before the exam (a Helm-like Deployment, a Role in kube-system)
kubectl create namespace platform >/dev/null
kubectl create deployment traefik -n platform --image=registry.k8s.io/pause:3.9 >/dev/null
kubectl annotate deployment traefik -n platform meta.helm.sh/release-name=traefik >/dev/null
kubectl create deployment plain -n platform --image=registry.k8s.io/pause:3.9 >/dev/null
kubectl create clusterrole platform-cr --verb=get --resource=pods >/dev/null
sleep 2

# an old snapshot format and a snapshot of the wrong shape must be refused
echo '{"namespaces": []}' > "$WORK/old.json"
check "an old-format snapshot is refused" bash -c "! python3 -I '$TOOL' label '$WORK/old.json' --exam e --run r"
check "nothing was labelled by the refused snapshot" bash -c "[ -z \"\$(kubectl get all,clusterrole,ns -A -l ck-x.io/created-by -o name)\" ]"

tool snapshot "$WORK/snap.json" || FAILED=1
sleep 2

# the exam setup
kubectl create namespace exam-ns >/dev/null
kubectl create deployment web -n exam-ns --image=registry.k8s.io/pause:3.9 >/dev/null
kubectl create clusterrole exam-cr --verb=get --resource=pods >/dev/null
kubectl create configmap exam-cm -n default --from-literal=a=b >/dev/null
kubectl create configmap sys-cm -n kube-system --from-literal=a=b >/dev/null

tool label "$WORK/snap.json" --exam mhagou-008 --run run-1 || FAILED=1
check "the new namespace is labelled with the exam" bash -c "kubectl get ns exam-ns -o jsonpath='{.metadata.labels}' | grep -q '\"ck-x.io/exam\":\"mhagou-008\"'"
check "the new cluster role is labelled" bash -c "kubectl get clusterrole -l ck-x.io/created-by=ck-x-simulator -o name | grep -q exam-cr"
check "nothing is labelled in default (protected)" bash -c "! kubectl get cm exam-cm -n default -l ck-x.io/created-by"
check "nothing is labelled in kube-system (protected)" bash -c "! kubectl get cm sys-cm -n kube-system -l ck-x.io/created-by"
check "the platform is not labelled" bash -c "[ -z \"\$(kubectl get deploy -n platform -l ck-x.io/created-by -o name; kubectl get clusterrole -l ck-x.io/created-by -o name | grep platform-cr)\" ]"
check "objects in the new namespace are not labelled one by one" bash -c "! kubectl get deploy web -n exam-ns -l ck-x.io/created-by"

# a snapshot of another cluster is refused: forge one
python3 -I - "$WORK/snap.json" "$WORK/other.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1])); s["cluster"] = "not-this-cluster"; json.dump(s, open(sys.argv[2], "w"))
PY
check "a snapshot of another cluster is refused" bash -c "! python3 -I '$TOOL' label '$WORK/other.json' --exam e --run r"

# the dangerous case: a snapshot that misses the existing objects (what the first version took) must not
# label them, because they were created before the snapshot
python3 -I - "$WORK/snap.json" "$WORK/partial.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
s["objects"] = {k: v for k, v in s["objects"].items() if k in ("namespaces",)}
s["objects"]["namespaces"] = s["objects"]["namespaces"]
json.dump(s, open(sys.argv[2], "w"))
PY
kubectl label deployment traefik plain -n platform --overwrite ck-x.io/probe- >/dev/null 2>&1
tool label "$WORK/partial.json" --exam e --run partial >/dev/null
check "a partial snapshot does not label the platform" bash -c "[ -z \"\$(kubectl get deploy -n platform -l ck-x.io/created-by -o name)\" ]"

# sweep: dry run first
out=$(tool sweep)
check "the dry run lists the exam namespace" bash -c "echo '$out' | grep -q 'Would delete namespace exam-ns'"
check "the dry run deletes nothing" exists ns exam-ns

# even if the platform were labelled by mistake, the sweep leaves it (Helm-managed, system namespaces)
kubectl label deployment traefik -n platform ck-x.io/created-by=ck-x-simulator >/dev/null
kubectl label configmap sys-cm -n kube-system ck-x.io/created-by=ck-x-simulator >/dev/null
kubectl label namespace kube-public ck-x.io/created-by=ck-x-simulator >/dev/null
tool sweep --yes --wait 120 || FAILED=1
check "the exam namespace is gone" bash -c "! kubectl get ns exam-ns"
check "the exam cluster role is gone" bash -c "! kubectl get clusterrole exam-cr"
check "a Helm-managed object is never deleted" exists deploy traefik -n platform
check "an object of kube-system is never deleted" exists cm sys-cm -n kube-system
check "kube-public is never deleted" exists ns kube-public
check "the unlabelled platform object is intact" exists deploy plain -n platform
check "the unlabelled cluster role is intact" exists clusterrole platform-cr

# the limit
for i in 1 2 3; do kubectl create clusterrole lim-$i --verb=get --resource=pods >/dev/null; kubectl label clusterrole lim-$i ck-x.io/created-by=ck-x-simulator >/dev/null; done
check "a sweep over the limit refuses to delete" bash -c "! python3 -I '$TOOL' sweep --yes --max 2"
check "nothing was deleted over the limit" exists clusterrole lim-1 lim-2 lim-3

[ "$FAILED" -eq 0 ] && echo "ALL OK" || { echo "SOME CHECKS FAILED"; exit 1; }
