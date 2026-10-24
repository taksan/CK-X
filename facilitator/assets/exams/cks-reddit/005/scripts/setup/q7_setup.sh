#!/bin/bash

# Setup for CKS-005 Question 7: strace of a container process from the node.
# Namespace trace-lab is exclusive. The Pod ledger-sync runs on node02. Its shell loop writes,
# reads and removes a file with a random name and tries to reach a random address (TEST-NET-2,
# RFC 5737, never routed). The expected values are stored outside the node, in the exam directory.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

NS="trace-lab"
DIR="/tmp/exam/cks-005-q7"
ensure_namespace "$NS"
kubectl delete pod ledger-sync -n "$NS" --ignore-not-found --now >/dev/null 2>&1

mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/* "${DIR:?}"/.expected

R1=$(shuf -i 1000-9999 -n 1); R2=$(shuf -i 10-250 -n 1); PORT=$(shuf -i 20000-29999 -n 1)
FILE_PATH="/var/run/.sync-$R1/state.tok"
IP="198.51.100.$R2"
cat > "$DIR/.expected" <<EOF
EXPECTED_FILE=$FILE_PATH
EXPECTED_ENDPOINT=$IP:$PORT
EOF

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ledger-sync
  namespace: ${NS}
spec:
  nodeName: $NODE02
  containers:
  - name: sync
    image: busybox:1.36.1
    command:
    - sh
    - -c
    - |
      mkdir -p $(dirname "$FILE_PATH")
      while true; do
        echo token > $FILE_PATH
        cat $FILE_PATH > /dev/null
        rm -f $FILE_PATH
        nc -w 1 $IP $PORT > /dev/null 2>&1
        sleep 4
      done
EOF

echo "Setup completed for CKS-005 Question 7 (namespace '$NS', findings directory $DIR)"
exit 0
