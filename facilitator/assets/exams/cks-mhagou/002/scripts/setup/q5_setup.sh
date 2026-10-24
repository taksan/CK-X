#!/bin/bash

# Setup for MHAGOU-002 Question 5: a local seccomp profile. Namespace alpha is exclusive.
# The profile to install is provided on the jumphost in /tmp/exam/mhagou-002-q5/auditing.json
# (defaultAction SCMP_ACT_LOG: every syscall is allowed and logged by the kernel). The kubelet
# profile directory of node01 does not exist yet: the candidate creates it. The node restore
# removes /var/lib/kubelet/seccomp.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="alpha"
DIR="/tmp/exam/mhagou-002-q5"

ensure_namespace "$NS"
kubectl delete pod nginx-auditing -n "$NS" --ignore-not-found --now >/dev/null 2>&1
ssh -o StrictHostKeyChecking=no node01 'rm -rf /var/lib/kubelet/seccomp'

mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*
cat > "$DIR/auditing.json" <<'EOF'
{
  "defaultAction": "SCMP_ACT_LOG"
}
EOF

echo "Setup completed for MHAGOU-002 Question 5 (namespace '$NS', profile in $DIR/auditing.json)"
exit 0
