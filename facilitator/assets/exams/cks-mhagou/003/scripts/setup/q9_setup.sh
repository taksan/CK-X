#!/bin/bash

# Setup for MHagou-003 Question 9: Pod Security Standards labels and a Localhost seccomp profile.
# The namespace secure-team is created BY THE CANDIDATE (exclusive to this question: removed here if
# a previous session left it). The profile profiles/audit.json is put on both workers under
# /var/lib/kubelet/seccomp (removed by the node restore at cleanup). The profile only LOGS the
# syscalls (the audit.json of the Kubernetes documentation): the source's allow-list of 36 syscalls
# cannot run nginx (CrashLoopBackOff), so "the Pod must run" would be unsatisfiable.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

kubectl delete namespace secure-team --ignore-not-found --wait=true --timeout=120s >/dev/null 2>&1 || true

for node in ${NODE01} ${NODE02}; do
  ssh -o StrictHostKeyChecking=no "$node" 'bash -s' <<'EOF'
mkdir -p /var/lib/kubelet/seccomp/profiles
cat > /var/lib/kubelet/seccomp/profiles/audit.json <<'JSON'
{
  "defaultAction": "SCMP_ACT_LOG"
}
JSON
EOF
done

echo "Setup completed for MHagou-003 Question 9 (profile profiles/audit.json on ${NODE01} and ${NODE02}; the namespace is created by the candidate)"
exit 0
