#!/bin/bash
# Validate the workloads are running and every Pod has a running istio-proxy sidecar.
# Istio injects it as a regular container (older versions) or as a native sidecar,
# i.e. an init container with restartPolicy Always (current versions): accept both.

NAMESPACE="${Q6_NAMESPACE:-payments}"
DEPLOYMENTS="payments-api payments-worker"

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "❌ Namespace '$NAMESPACE' not found"
  exit 1
fi

# the workloads must still exist and be fully available (no free marks by deleting them)
for d in $DEPLOYMENTS; do
  READY=$(kubectl get deployment "$d" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  WANT=$(kubectl get deployment "$d" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null)
  if [ -z "$READY" ] || [ -z "$WANT" ] || [ "$READY" != "$WANT" ]; then
    echo "❌ Deployment '$d' is missing or not fully ready (ready: ${READY:-0}/${WANT:-?})"
    exit 1
  fi
done

MISSING=$(kubectl get pods -n "$NAMESPACE" -o json | jq -r '
  .items[] | select(.metadata.deletionTimestamp == null)
  | select(
      ( [ ((.spec.containers // []) + (.spec.initContainers // []))[] | select(.name == "istio-proxy") ] | length ) == 0
      or
      ( [ ((.status.containerStatuses // []) + (.status.initContainerStatuses // []))[] | select(.name == "istio-proxy" and .ready == true) ] | length ) == 0
    )
  | .metadata.name')

if [ -n "$MISSING" ]; then
  echo "❌ These Pods have no running istio-proxy sidecar:"
  echo "$MISSING" | sed 's/^/   /'
  exit 1
fi

echo "✅ All Pods in '$NAMESPACE' run with an istio-proxy sidecar"
exit 0
