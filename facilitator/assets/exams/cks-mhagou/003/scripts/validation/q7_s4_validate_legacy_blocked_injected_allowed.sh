#!/bin/bash
# Validate by behaviour: the legacy Pod (no sidecar, namespace legacy-zone) cannot reach the payment
# service over plaintext while an injected client inside restricted-zone can

NS="restricted-zone"
URL="http://payment-service.restricted-zone.svc.cluster.local:8000/get"

READY=$(kubectl get pods -n "$NS" -l app=payment-service -o json 2>/dev/null | jq -r '[.items[] | select(.metadata.deletionTimestamp == null) | (([.status.containerStatuses[]?, .status.initContainerStatuses[]?] | map(select(.name == "istio-proxy")) | .[0].ready) // false)] | (length > 0 and all)')
[ "$READY" = "true" ] || { echo "❌ payment-service has no ready istio-proxy sidecar: nothing to credit"; exit 1; }
[ "$(kubectl get pod legacy -n legacy-zone -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ] \
  || { echo "❌ The legacy client Pod of legacy-zone is not running"; exit 1; }

# the legacy client is blocked (a policy takes a few seconds to reach the proxies)
for i in $(seq 1 15); do
  C=$(kubectl exec -n legacy-zone legacy -- curl -s -o /dev/null -m 5 -w '%{http_code}' "$URL" 2>/dev/null)
  [ "$C" != "200" ] && break
  sleep 3
done
[ "$C" != "200" ] || { echo "❌ The legacy Pod (no sidecar) still reaches payment-service over plaintext (HTTP 200)"; exit 1; }

# an injected client of the namespace still gets through
P="ckx-probe-$RANDOM$RANDOM"
kubectl run "$P" -n "$NS" --image=curlimages/curl:8.10.1 --restart=Never --command -- sleep 120 >/dev/null 2>&1 \
  || { echo "❌ Cannot create the validation client Pod in $NS"; exit 1; }
OK=0
for i in $(seq 1 40); do
  [ "$(kubectl get pod "$P" -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ] && break
  sleep 3
done
for i in $(seq 1 10); do
  C=$(kubectl exec -n "$NS" "$P" -c "$P" -- curl -s -o /dev/null -m 5 -w '%{http_code}' "$URL" 2>/dev/null)
  [ "$C" = "200" ] && { OK=1; break; }
  sleep 3
done
kubectl delete pod "$P" -n "$NS" --force --grace-period=0 >/dev/null 2>&1
[ "$OK" = "1" ] || { echo "❌ An injected client inside restricted-zone cannot reach payment-service (HTTP ${C:-none})"; exit 1; }

echo "✅ The legacy Pod is blocked (HTTP ${C:-reset}) and an injected client reaches payment-service"
exit 0
