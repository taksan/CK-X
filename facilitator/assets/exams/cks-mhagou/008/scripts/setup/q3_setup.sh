#!/bin/bash

# Setup for MHAGOU-008 Question 3: egress NetworkPolicy that blocks two malicious ranges.
# Namespace threat-prevention is exclusive: two Pods (lab-client, lab-peer) serving HTTP on 8080,
# no NetworkPolicy.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="threat-prevention"
ensure_namespace "$NS"
kubectl delete networkpolicy --all -n "$NS" >/dev/null 2>&1

for pod in lab-client lab-peer; do
kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${pod}
  namespace: ${NS}
  labels:
    app: ${pod}
spec:
  containers:
  - name: ${pod}
    image: busybox:1.36.1
    command: ["sh", "-c", "mkdir -p /www && echo ok > /www/index.html && exec httpd -f -p 8080 -h /www"]
    ports:
    - {name: http, containerPort: 8080}
    readinessProbe:
      tcpSocket: {port: 8080}
      initialDelaySeconds: 1
      periodSeconds: 2
EOF
done

kubectl wait --for=condition=Ready pod/lab-client pod/lab-peer -n "$NS" --timeout=180s >/dev/null || { echo "WARNING: the Pods are not ready"; exit 1; }

echo "Setup completed for MHAGOU-008 Question 3 (namespace '$NS')"
exit 0
