#!/bin/bash
# Service europe in world forwards to the ready nginx backend of the namespace europe: a Service
# without selector with EndpointSlices (or Endpoints) to the backend Pods or to the Service of europe,
# or an ExternalName Service pointing at it

J=$(kubectl get svc europe -n world -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Service 'europe' not found in namespace 'world'"; exit 1; }
echo "$J" | jq -e 'any(.spec.ports[]?; .port == 80)' >/dev/null || { echo "❌ Service 'europe' in world does not expose port 80"; exit 1; }

if [ "$(echo "$J" | jq -r '.spec.type')" = "ExternalName" ]; then
  EXT=$(echo "$J" | jq -r '.spec.externalName')
  case "$EXT" in
    *.europe.svc|*.europe.svc.cluster.local) echo "✅ Service 'europe' is an ExternalName Service to the namespace europe ($EXT)"; exit 0 ;;
    *) echo "❌ The ExternalName '$EXT' does not point to a Service of the namespace europe"; exit 1 ;;
  esac
fi

# addresses the Service forwards to
ADDRS=$(kubectl get endpointslices -n world -l "kubernetes.io/service-name=europe" -o json 2>/dev/null | jq -r '[.items[].endpoints[]? | select(.conditions.ready != false) | .addresses[]] | .[]')
[ -n "$ADDRS" ] || { echo "❌ Service 'europe' in world has no endpoints (a Service without selector needs an EndpointSlice or Endpoints)"; exit 1; }

PODS=$(kubectl get pods -n europe -o json 2>/dev/null | jq -r '[.items[] | select(.status.phase == "Running" and .metadata.deletionTimestamp == null) | .status.podIP] | .[]')
CIPS=$(kubectl get svc -n europe -o json 2>/dev/null | jq -r '[.items[] | .spec.clusterIP] | .[]')
for a in $ADDRS; do
  echo "$PODS $CIPS" | tr ' ' '\n' | grep -qx "$a" || { echo "❌ The endpoint $a of Service 'europe' is neither a Pod nor a Service of the namespace europe"; exit 1; }
done

echo "✅ Service 'europe' in world forwards to the nginx backend of the namespace europe"
exit 0
