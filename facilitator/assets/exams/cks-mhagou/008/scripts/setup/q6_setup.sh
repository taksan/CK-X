#!/bin/bash

# Setup for MHAGOU-008 Question 6: a seccomp profile that blocks ptrace and process_vm_readv.
# Namespace secure-runtime is exclusive. The Pod secure-app runs on node01 with an Unconfined
# seccomp profile; /var/lib/kubelet/seccomp does not exist on node01 (the candidate creates the
# profile there and re-creates the Pod, the seccomp profile of a Pod cannot be changed in place).

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

NS="secure-runtime"
ensure_namespace "$NS"
kubectl delete pod secure-app -n "$NS" --ignore-not-found --now >/dev/null 2>&1

ssh -o StrictHostKeyChecking=no node01 'rm -rf /var/lib/kubelet/seccomp'

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: ${NS}
spec:
  nodeName: ${NODE01}
  securityContext:
    seccompProfile:
      type: Unconfined
  containers:
  - name: nginx-container
    image: nginx:1.27-alpine
    ports:
    - containerPort: 80
    readinessProbe:
      httpGet: {path: /, port: 80}
      initialDelaySeconds: 2
      periodSeconds: 3
EOF

kubectl wait --for=condition=Ready pod/secure-app -n "$NS" --timeout=180s >/dev/null || { echo "WARNING: secure-app is not ready"; exit 1; }

echo "Setup completed for MHAGOU-008 Question 6 (namespace '$NS', Pod on ${NODE01})"
exit 0
