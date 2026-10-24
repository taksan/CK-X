#!/bin/bash
# Source this file: starts the lab registry (plain HTTP, no authentication) in the namespace
# ckx-registry, exposed on a NodePort, and sets REGISTRY to an address that the jumphost reaches.
# It is infrastructure shared by the image signing questions (each one uses its own repository);
# the session cleanup deletes the namespace, so every exam starts with an empty registry.

source "$(dirname "${BASH_SOURCE[0]}")/nodes.sh"

REGISTRY_NS="ckx-registry"
REGISTRY_NODEPORT=30500

ensure_registry() {
  ensure_namespace "$REGISTRY_NS"
  kubectl apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata: {name: registry, namespace: ${REGISTRY_NS}}
spec:
  replicas: 1
  selector: {matchLabels: {app: registry}}
  template:
    metadata: {labels: {app: registry}}
    spec:
      containers:
      - name: registry
        image: registry:2
        ports: [{containerPort: 5000}]
---
apiVersion: v1
kind: Service
metadata: {name: registry, namespace: ${REGISTRY_NS}}
spec:
  type: NodePort
  selector: {app: registry}
  ports: [{port: 5000, targetPort: 5000, nodePort: ${REGISTRY_NODEPORT}}]
EOF
  kubectl rollout status deploy/registry -n "$REGISTRY_NS" --timeout=180s >/dev/null 2>&1 || return 1
  local ip
  ip=$(kubectl get node "$NODE01" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
  REGISTRY="${ip}:${REGISTRY_NODEPORT}"
  for i in $(seq 1 30); do
    curl -fsS --connect-timeout 3 -m 5 "http://$REGISTRY/v2/" >/dev/null 2>&1 && return 0
    sleep 2
  done
  return 1
}

# registry_digest <repo> <tag>: digest of the manifest behind a tag
registry_digest() {
  curl -fsSI -H 'Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json' \
    "http://$REGISTRY/v2/$1/manifests/$2" | tr -d '\r' | awk 'tolower($1)=="docker-content-digest:" {print $2}'
}
