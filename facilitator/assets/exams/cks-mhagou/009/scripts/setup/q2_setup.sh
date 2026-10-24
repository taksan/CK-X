#!/bin/bash

# Setup for MHagou CKS exam 9, Question 2: projected ServiceAccount token.
# Namespace monitoring is exclusive. The Deployment manifest the candidate edits is
# /tmp/exam/mhagou-009-q2/deployment.yaml (on the jumphost).

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="monitoring"
DIR="/tmp/exam/mhagou-009-q2"
ensure_namespace "$NS"

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: stats-monitor-sa
  namespace: ${NS}
automountServiceAccountToken: true
EOF

mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*
cat > "$DIR/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stats-monitor
  namespace: ${NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: stats-monitor
  template:
    metadata:
      labels:
        app: stats-monitor
    spec:
      serviceAccountName: stats-monitor-sa
      containers:
      - name: stats-monitor-container
        image: busybox:1.36.1
        command: ["sh", "-c", "while :; do sleep 3600; done"]
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            memory: 64Mi
EOF

kubectl delete deployment stats-monitor -n "$NS" --ignore-not-found --wait=true >/dev/null 2>&1
kubectl apply -f "$DIR/deployment.yaml" >/dev/null

echo "Setup completed for MHagou exam 9 Question 2 (namespace '$NS', manifest $DIR/deployment.yaml)"
exit 0
