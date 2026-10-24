#!/bin/bash
#
# Spins up (or deletes) an extra kind cluster used as a parallel "test lane" for the API-level
# questions of the exams: Cilium, MetalLB, Traefik and Istio with the same versions as the lab
# cluster (Cilium 1.18.4, Traefik chart 37.1.0 / v3.5.1, Istio 1.29.9). Nodes are docker containers:
# there is no ssh to them, so node-level questions still need the real cluster.
#
# Usage:
#   scripts/start-kind-lane.sh <lane-number> [kubeconfig-output]   lane 2 -> cluster "kind2", context kind-kind2
#   scripts/start-kind-lane.sh --delete <lane-number>
#
# Lane 1 is the cluster "kind" created by start-kind-with-cilium.sh (MetalLB pool 172.22.0.200-250).
# Lane N uses the MetalLB pool <docker subnet prefix>.<N-1>.200-250 so pools never overlap, and writes a
# flattened kubeconfig (default ~/.kube/kind<N>.kubeconfig) that tests use through KUBECONFIG, so the
# current context of ~/.kube/config is never changed.
#
# Requires: docker, kind, kubectl, helm, cilium (cilium-cli) on the PATH.

set -eo pipefail

CILIUM_VERSION="1.18.4"
METALLB_URL="https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml"
TRAEFIK_CHART="37.1.0"
ISTIO_VERSION="1.29.9"

info() { echo -e "\033[1;36m[INFO][$(date '+%Y-%m-%d %H:%M:%S')] $*\033[0m"; }
die()  { echo "ERROR: $*" >&2; exit 1; }

for tool in docker kind kubectl helm cilium; do
  command -v "$tool" >/dev/null || die "$tool is required on the PATH"
done

if [ "$1" = "--delete" ]; then
  N="${2:?lane number required}"
  info "Deleting the kind cluster kind${N}"
  kind delete cluster --name "kind${N}"
  rm -f "$HOME/.kube/kind${N}.kubeconfig"
  exit 0
fi

N="${1:?usage: $0 <lane-number> [kubeconfig-output] | $0 --delete <lane-number>}"
[[ "$N" =~ ^[2-9]$ ]] || die "lane number must be 2..9 (lane 1 is the cluster 'kind' of start-kind-with-cilium.sh)"
NAME="kind${N}"
KUBECONFIG_OUT="${2:-$HOME/.kube/${NAME}.kubeconfig}"
CONTEXT="kind-${NAME}"
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

cat > "$WORKDIR/kind-config.yaml" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  podSubnet: 192.168.0.0/16
nodes:
- role: control-plane
- role: worker
EOF

if kind get clusters | grep -qx "$NAME"; then
  info "The kind cluster $NAME already exists: reusing it"
else
  info "Creating the kind cluster $NAME (2 nodes, no default CNI)"
  # --kubeconfig keeps the new context out of ~/.kube/config (its current context stays as it is)
  kind create cluster --name "$NAME" --config "$WORKDIR/kind-config.yaml" --kubeconfig "$KUBECONFIG_OUT"
fi

# a private kubeconfig: tests use it through KUBECONFIG
kind export kubeconfig --name "$NAME" --kubeconfig "$KUBECONFIG_OUT"
chmod 600 "$KUBECONFIG_OUT"
export KUBECONFIG="$KUBECONFIG_OUT"
info "kubeconfig: $KUBECONFIG_OUT (context $CONTEXT)"

info "Cilium $CILIUM_VERSION"
docker pull -q "quay.io/cilium/cilium:v${CILIUM_VERSION}" >/dev/null || true
kind load docker-image "quay.io/cilium/cilium:v${CILIUM_VERSION}" --name "$NAME" >/dev/null 2>&1 || true
if ! helm ls -n kube-system 2>/dev/null | grep -q '^cilium'; then
  cilium install --version "$CILIUM_VERSION" --wait
fi

info "MetalLB"
kubectl apply -f "$METALLB_URL" >/dev/null
kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=180s
SUBNET=$(docker network inspect kind -f '{{range .IPAM.Config}}{{ if (eq 4 (len (split .Subnet "." ))) }}{{ (index (split .Subnet "/") 0 )}}{{end}}{{end}}')
PREFIX=$(echo "$SUBNET" | awk -F. '{print $1"."$2}')
START="${PREFIX}.$((N - 1)).200"
END="${PREFIX}.$((N - 1)).250"
info "MetalLB pool ${START}-${END}"
for i in 1 2 3 4 5 6; do
  if cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: lane
  namespace: metallb-system
spec:
  addresses:
  - ${START}-${END}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: lane
  namespace: metallb-system
EOF
  then break; fi
  sleep 10
done

info "Istio $ISTIO_VERSION (base + istiod)"
cat > "$WORKDIR/istiod-values.yaml" <<EOF
pilot:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
EOF
ISTIO_REPO="https://istio-release.storage.googleapis.com/charts"
helm upgrade --install istio-base base --repo "$ISTIO_REPO" --version "$ISTIO_VERSION" -n istio-system --create-namespace --wait --timeout 5m
helm upgrade --install istiod istiod --repo "$ISTIO_REPO" --version "$ISTIO_VERSION" -n istio-system -f "$WORKDIR/istiod-values.yaml" --wait --timeout 8m

info "Traefik chart $TRAEFIK_CHART"
cat > "$WORKDIR/traefik-values.yaml" <<EOF
ingressClass:
  enabled: true
  isDefaultClass: true
resources:
  requests:
    cpu: 100m
    memory: 64Mi
service:
  type: LoadBalancer
EOF
helm upgrade --install traefik traefik --repo https://traefik.github.io/charts --version "$TRAEFIK_CHART" -n traefik --create-namespace -f "$WORKDIR/traefik-values.yaml" --wait --timeout 8m

info "Done. Traefik address: $(kubectl get svc traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
echo "Use it with:  export KUBECONFIG=$KUBECONFIG_OUT    (lock: flock /tmp/ckx-kind${N}.lock ...)"
