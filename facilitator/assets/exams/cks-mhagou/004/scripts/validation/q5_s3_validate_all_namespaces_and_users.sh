#!/bin/bash
# Item 3: "all Secret requests": every namespace, cluster-wide requests and every kind of user, logged at
# exactly Metadata (a higher level would write the Secret contents into the audit log)

source "$(dirname "$0")/../lib/nodes.sh"

export AUDIT_POLICY_LOCAL_FILE="${Q5_POLICY:-/tmp/exam/mhagou-004-q5/audit-policy.yaml}"
source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

FAIL=0
for ns in kube-system default team-b payments; do
  check_audit_level "Secrets in namespace $ns" Metadata "" secrets "" "$ns" get || FAIL=1
done
check_audit_level "Cluster-wide list of Secrets" Metadata "" secrets "" "" list || FAIL=1
for u in alice system:serviceaccount:team-a:builder system:node:$NODE01 system:kube-controller-manager; do
  AUDIT_USER="$u" check_audit_level "Secret request of $u" Metadata "" secrets "" team-a get || FAIL=1
done
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ Secret requests of every namespace and user are logged at Metadata"
exit 0
