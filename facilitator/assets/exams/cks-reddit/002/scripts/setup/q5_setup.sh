#!/bin/bash

# Setup for Question 5: Pods mounting the container runtime socket in dev-ops

source "$(dirname "$0")/../lib/wait-cluster.sh"

NAMESPACE="dev-ops"

# Create namespace if it doesn't exist
ensure_namespace "$NAMESPACE"

# billing mounts the containerd socket from the host: anyone who can talk to it
# can start privileged containers and take over the node
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: billing
  namespace: ${NAMESPACE}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: billing
  template:
    metadata:
      labels:
        app: billing
    spec:
      containers:
      - name: billing
        image: busybox
        command: ["sh", "-c", "sleep 3600"]
        volumeMounts:
        - name: host-run
          mountPath: /run/containerd/containerd.sock
      volumes:
      - name: host-run
        hostPath:
          path: /run/containerd/containerd.sock
          type: Socket
EOF

# notifier only reads the node logs: it must be left untouched
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notifier
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: notifier
  template:
    metadata:
      labels:
        app: notifier
    spec:
      containers:
      - name: notifier
        image: busybox
        command: ["sh", "-c", "sleep 3600"]
        volumeMounts:
        - name: host-logs
          mountPath: /var/log/node
          readOnly: true
      volumes:
      - name: host-logs
        hostPath:
          path: /var/log
EOF

# Remove the previous version of this question's workload, if any
kubectl delete deployment docker-client runtime-client log-agent -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1 || true

echo "Setup completed for CKS-002 Question 5 in namespace '$NAMESPACE'"
exit 0
