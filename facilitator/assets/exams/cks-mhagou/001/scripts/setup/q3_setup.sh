#!/bin/bash

# Setup for MHagou-001 Question 3 (source "auditing-binaries", three parts):
#  a) kubelet of the worker node02 accepts anonymous requests (anonymous.enabled: true): the candidate runs
#     kube-bench, finds check 4.2.1 and fixes the kubelet configuration. The node restore puts the
#     config back (and restarts the kubelet).
#  b) checksums: copies of three control plane manifests and a SHA512SUMS file with the known-good hashes;
#     one manifest (random) was modified. Files on the jumphost.
#  c) a container that runs a process called "cryptominer" on node01, among two ordinary ones
#     (namespace crypto-watch is exclusive). restartPolicy Never: once its container is stopped and removed
#     kubelet does not bring it back.
# The "miner" is a harmless shell script named cryptominer (a copy of busybox under that name would not
# start: busybox picks the applet from its name); Falco is not part of this question.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

NS="crypto-watch"
DIR="/tmp/exam/mhagou-001-q3"

# ---- a) kubelet of node02: anonymous authentication enabled
ssh -o StrictHostKeyChecking=no node02 'bash -s' <<'EOF'
set -e
yq -i '.authentication.anonymous.enabled = true' /var/lib/kubelet/config.yaml
systemctl restart kubelet
EOF
for i in $(seq 1 60); do
  [ "$(kubectl get node "$NODE02" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)" = "True" ] && break
  sleep 3
done

# ---- b) manifests and checksums
mkdir -p "${DIR:?}/manifests"
rm -rf "${DIR:?}"/*
mkdir -p "$DIR/manifests"
for m in kube-apiserver kube-controller-manager kube-scheduler; do
  ssh -o StrictHostKeyChecking=no k8s-api-server "cat /etc/kubernetes/manifests/$m.yaml" > "$DIR/manifests/$m.yaml"
done
(cd "$DIR/manifests" && sha512sum kube-apiserver.yaml kube-controller-manager.yaml kube-scheduler.yaml > "$DIR/SHA512SUMS")
TAMPERED=$(printf '%s\n' kube-apiserver.yaml kube-controller-manager.yaml kube-scheduler.yaml | shuf -n 1)
printf '    - --ckx-extra-flag=%s\n' "$RANDOM" >> "$DIR/manifests/$TAMPERED"
echo "TAMPERED=$TAMPERED" > "$DIR/.state"

# ---- c) the containers on node01
ensure_namespace "$NS"
kubectl delete pod batch-runner metrics-agent log-shipper -n "$NS" --ignore-not-found --now >/dev/null 2>&1
kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: batch-runner
  namespace: ${NS}
spec:
  nodeName: ${NODE01}
  restartPolicy: Never
  containers:
  - name: runner
    image: busybox:1.36.1
    command:
    - sh
    - -c
    - |
      printf '#!/bin/sh\nwhile :; do sleep 30; done\n' > /bin/cryptominer
      chmod +x /bin/cryptominer
      exec /bin/cryptominer
---
apiVersion: v1
kind: Pod
metadata:
  name: metrics-agent
  namespace: ${NS}
spec:
  nodeName: ${NODE01}
  containers:
  - {name: agent, image: "busybox:1.36.1", command: ["sleep", "86400"]}
---
apiVersion: v1
kind: Pod
metadata:
  name: log-shipper
  namespace: ${NS}
spec:
  nodeName: ${NODE01}
  containers:
  - {name: shipper, image: "busybox:1.36.1", command: ["sleep", "86400"]}
EOF

echo "Setup completed for MHagou-001 Question 3 ($NODE02 kubelet, files in $DIR, namespace '$NS' on $NODE01)"
exit 0
