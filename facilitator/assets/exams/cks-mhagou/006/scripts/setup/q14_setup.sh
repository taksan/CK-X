#!/bin/bash

# Setup for MHagou-006 Question 14: inspect a container from the node (strace, crictl, /proc).
# Namespace inspect-lab is exclusive. The Pod test runs on node01 as a random non-root uid and keeps
# running one process of the image (an applet chosen at random: no binary is created at run time).
# The expected values are kept on the jumphost in /tmp/exam/mhagou-006-q14/.expected.

source "$(dirname "$0")/../lib/nodes.sh"

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="inspect-lab"
DIR="/tmp/exam/mhagou-006-q14"
ensure_namespace "$NS"
kubectl delete pod test -n "$NS" --ignore-not-found --now >/dev/null 2>&1

UID_=$(shuf -i 3001-3999 -n 1)
PROC=$(printf '%s\n' hostname uptime date id | shuf -n 1)

mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/* "${DIR:?}"/.expected
cat > "$DIR/.expected" <<EOF
EXPECTED_PROCESS=$PROC
EXPECTED_UID=$UID_
EXPECTED_IMAGE=busybox
EOF
ssh -o StrictHostKeyChecking=no node01 "mkdir -p $DIR && rm -f ${DIR:?}/*"
ssh -o StrictHostKeyChecking=no node01 "cat > $DIR/report.txt" <<'TPL'
process=<name of the process>
uid=<numeric user id>
image=<image repository without the tag>
TPL

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata: {name: test, namespace: ${NS}}
spec:
  nodeName: ${NODE01}
  securityContext: {runAsUser: ${UID_}, runAsGroup: ${UID_}}
  containers:
  - name: main
    image: busybox:1.36.1
    command: ["sh", "-c", "while true; do sleep 3; /bin/${PROC} > /dev/null 2>&1; done"]
EOF

echo "Setup completed for MHagou-006 Question 14 (namespace '$NS', Pod on ${NODE01}, report directory $DIR on ${NODE01})"
exit 0
