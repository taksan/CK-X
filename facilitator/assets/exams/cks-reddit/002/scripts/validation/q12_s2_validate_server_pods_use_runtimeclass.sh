#!/bin/bash
# Validate the workloads in the server namespace run with runtimeClassName sandboxed

NAMESPACE="${Q12_NAMESPACE:-server}"
RUNTIMECLASS="sandboxed"
DEPLOYMENTS="${Q12_DEPLOYMENTS:-workload1 workload2 workload3}"

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "❌ Namespace '$NAMESPACE' not found"
  exit 1
fi

# the workloads must still exist and be fully ready (no free marks by deleting them)
for d in $DEPLOYMENTS; do
  READY=$(kubectl get deployment "$d" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  WANT=$(kubectl get deployment "$d" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null)
  if [ -z "$WANT" ] || [ "${READY:-0}" != "$WANT" ]; then
    echo "❌ Deployment '$d' is missing or not fully ready (ready: ${READY:-0}/${WANT:-?})"
    exit 1
  fi
done

# Pods that are only terminating (old ones during a rollout) do not count
BAD=$(kubectl get pods -n "$NAMESPACE" -o json | jq -r --arg rc "$RUNTIMECLASS" '
  .items[] | select(.metadata.deletionTimestamp == null)
  | select(.spec.runtimeClassName != $rc or .status.phase != "Running")
  | "\(.metadata.name) (runtimeClassName=\(.spec.runtimeClassName // "none"), phase=\(.status.phase))"')

if [ -n "$BAD" ]; then
  echo "❌ These Pods in '$NAMESPACE' do not run with runtimeClassName '$RUNTIMECLASS':"
  echo "$BAD" | sed 's/^/   /'
  exit 1
fi

echo "✅ All workloads in '$NAMESPACE' are running with runtimeClassName '$RUNTIMECLASS'"
exit 0
