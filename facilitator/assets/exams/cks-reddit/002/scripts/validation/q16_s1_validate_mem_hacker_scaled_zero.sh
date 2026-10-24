#!/bin/bash
# Validate the offending Deployment (telemetry-agent) is scaled to 0 and the harmless
# Deployments were left running

NAMESPACE="${Q16_NAMESPACE:-batch-ops}"
OFFENDER="${Q16_DEPLOY:-telemetry-agent}"
HARMLESS="${Q16_HARMLESS:-image-resizer email-sender}"

if ! kubectl get deployment "$OFFENDER" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "❌ The offending Deployment was deleted; it should be scaled down, not deleted"
  exit 1
fi

# status fields are omitted (not "0") when there are no replicas, so only spec.replicas is compared
REPLICAS=$(kubectl get deployment "$OFFENDER" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null)
if [ "${REPLICAS:-}" != "0" ]; then
  echo "❌ The Deployment that reads /dev/mem is still running (spec.replicas=${REPLICAS:-unset})"
  exit 1
fi

# pods that are only terminating do not count
RUNNING=$(kubectl get pods -n "$NAMESPACE" -l "app=$OFFENDER" -o json 2>/dev/null \
  | jq '[.items[] | select(.metadata.deletionTimestamp == null)] | length')
if [ "${RUNNING:-0}" != "0" ]; then
  echo "❌ $RUNNING Pod(s) of the offending Deployment are still running"
  exit 1
fi

# the harmless workloads must keep running
for d in $HARMLESS; do
  READY=$(kubectl get deployment "$d" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  WANT=$(kubectl get deployment "$d" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null)
  if [ -z "$WANT" ] || [ "$WANT" = "0" ] || [ "${READY:-0}" != "$WANT" ]; then
    echo "❌ Deployment '$d' does not access /dev/mem and should have been left running"
    exit 1
  fi
done

echo "✅ Only the Deployment that reads /dev/mem was scaled to 0; the other workloads are still running"
exit 0
