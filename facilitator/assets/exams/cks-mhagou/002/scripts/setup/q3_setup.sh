#!/bin/bash

# Setup for MHAGOU-002 Question 3: AppArmor profile on node01. Namespace apparmor-lab is exclusive.
#
# The profile spectacleapp is prepared in /etc/apparmor.d on node01 (not loaded: the candidate
# loads it). It denies reading /data/records. The Pod apparmor-pod runs privileged on node01 and
# mounts a ConfigMap at /data/records, so today it can read it. The node restore (checkpoint)
# unloads the profile and removes the file.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

NS="apparmor-lab"

ssh -o StrictHostKeyChecking=no node01 'bash -s' <<'EOF'
set -e
cat > /etc/apparmor.d/spectacleapp <<'PROFILE'
#include <tunables/global>
profile spectacleapp flags=(attach_disconnected,mediate_deleted) {
    #include <abstractions/base>
    file,
    network,
    capability,
    # the container runtime must be able to stop the container
    signal (receive) peer=runc,
    signal (receive) peer=unconfined,
    signal (receive) peer=cri-containerd.apparmor.d,
    # reading the records is what this profile forbids
    deny /data/records/ r,
    deny /data/records/** r,
}
PROFILE
EOF

ensure_namespace "$NS"
kubectl delete pod apparmor-pod -n "$NS" --ignore-not-found --now >/dev/null 2>&1
kubectl delete serviceaccount test-sa -n "$NS" --ignore-not-found >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: records
  namespace: ${NS}
data:
  read-test: "harmless fixture\n"
---
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-pod
  namespace: ${NS}
  labels:
    run: nginx
spec:
  nodeName: ${NODE01}
  containers:
  - name: nginx
    image: nginx:alpine
    securityContext:
      privileged: true
    ports:
    - containerPort: 80
    volumeMounts:
    - name: records
      mountPath: /data/records
      readOnly: true
  volumes:
  - name: records
    configMap:
      name: records
EOF

echo "Setup completed for MHAGOU-002 Question 3 (namespace '$NS', profile in /etc/apparmor.d/spectacleapp on ${NODE01})"
exit 0
