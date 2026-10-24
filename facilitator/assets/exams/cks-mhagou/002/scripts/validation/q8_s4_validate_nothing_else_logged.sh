#!/bin/bash
# The policy logs nothing else: other operations on pods of test, other resources of test, pods of
# other namespaces. Credited only when the requested events are logged (otherwise an empty policy
# would be a free mark).

export AUDIT_POLICY_FILE=/etc/kubernetes/test-audit.yaml
source "$(dirname "$0")/../lib/audit-policy.sh"
load_audit_policy || exit 1

[ "$(audit_level "" pods "" test delete)" = "Metadata" ] || { echo "❌ The requested events are not logged yet (pod deletes in test), so the exclusions cannot be credited"; exit 1; }

FAIL=0
check_audit_level "Pod creation in test" None "" pods "" test create || FAIL=1
check_audit_level "Pod reads in test" None "" pods "" test get || FAIL=1
check_audit_level "Secret deletes in test" None "" secrets "" test delete || FAIL=1
check_audit_level "ConfigMap updates in test" None "" configmaps "" test update || FAIL=1
check_audit_level "Pod deletes in kube-system" None "" pods "" kube-system delete || FAIL=1
check_audit_level "Pod updates in another namespace" None "" pods "" spectacle update || FAIL=1
check_audit_level "Node updates" None "" nodes "" "" update || FAIL=1
[ "$FAIL" -eq 0 ] || exit 1

echo "✅ Only deletes and updates of pods in the namespace test are logged"
exit 0
