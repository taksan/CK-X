#!/bin/bash
# Validate the running payment-service Pods have a ready Istio proxy (the Pods existed before the
# namespace was labelled: they have to be recreated)

NS="restricted-zone"
J=$(kubectl get pods -n "$NS" -l app=payment-service -o json 2>/dev/null)
N=$(echo "$J" | jq '[.items[] | select(.metadata.deletionTimestamp == null)] | length')
[ "${N:-0}" -ge 1 ] || { echo "❌ No payment-service Pod in namespace '$NS'"; exit 1; }

BAD=$(echo "$J" | jq -r '[.items[] | select(.metadata.deletionTimestamp == null) | select((([.status.containerStatuses[]?, .status.initContainerStatuses[]?] | map(select(.name == "istio-proxy")) | .[0].ready) // false) != true) | .metadata.name] | join(",")')
[ -z "$BAD" ] || { echo "❌ These payment-service Pods have no ready istio-proxy sidecar: $BAD (a Pod is injected only when it is created: restart the Deployment)"; exit 1; }

echo "✅ All $N payment-service Pod(s) run with a ready Istio proxy"
exit 0
