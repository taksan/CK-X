#!/bin/bash

# Setup for MHagou-006 Question 7: run a Deployment in a gVisor sandbox. Namespace sandbox-lab is
# exclusive. The Deployment report-api (2 replicas, pinned to node02, where runsc is installed) runs
# in the default runtime; the RuntimeClass not-trusted does not exist (cluster-scoped, removed by the
# session cleanup).

source "$(dirname "$0")/../lib/nodes.sh"

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="sandbox-lab"
ensure_namespace "$NS"
kubectl delete runtimeclass not-trusted --ignore-not-found >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata: {name: report-api, namespace: ${NS}}
spec:
  replicas: 2
  selector: {matchLabels: {app: report-api}}
  template:
    metadata: {labels: {app: report-api}}
    spec:
      nodeSelector: {kubernetes.io/hostname: ${NODE02}}
      containers:
      - {name: api, image: "busybox:1.36.1", command: ["sh", "-c", "sleep 86400"]}
EOF

echo "Setup completed for MHagou-006 Question 7 (namespace '$NS')"
exit 0
