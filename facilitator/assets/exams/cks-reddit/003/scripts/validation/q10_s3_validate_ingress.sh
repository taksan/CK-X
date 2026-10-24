#!/bin/bash
# Validate the Ingress: host bingo.com, TLS with bingo-tls, backend = a Service that routes to shop-web

NS="web-tls"

ING=$(kubectl get ingress -n "$NS" -o json 2>/dev/null | jq -c '.items[] | select([.spec.rules[]? | select(.host == "bingo.com")] | length > 0)' | head -1)
if [ -z "$ING" ]; then
  echo "❌ No Ingress for the host bingo.com in namespace '$NS'"
  exit 1
fi

if ! echo "$ING" | jq -e '[.spec.tls[]? | select(.secretName == "bingo-tls" and ((.hosts // []) | index("bingo.com") != null))] | length > 0' >/dev/null; then
  echo "❌ The Ingress has no TLS entry for bingo.com using the secret 'bingo-tls'"
  exit 1
fi

CLASS=$(echo "$ING" | jq -r '.spec.ingressClassName // .metadata.annotations["kubernetes.io/ingress.class"] // ""')
if [ -z "$CLASS" ] && ! kubectl get ingressclass -o json | jq -e '[.items[] | select(.metadata.annotations["ingressclass.kubernetes.io/is-default-class"] == "true")] | length > 0' >/dev/null; then
  echo "❌ The Ingress has no ingressClassName and the cluster has no default IngressClass"
  exit 1
fi

# the backend Service must select shop-web
BACKEND=$(echo "$ING" | jq -r '[.spec.rules[] | select(.host == "bingo.com") | .http.paths[]?.backend.service.name] | first // ""')
LABELS=$(kubectl get pod shop-web -n "$NS" -o json 2>/dev/null | jq -c '.metadata.labels // {}')
if [ -z "$BACKEND" ] || ! kubectl get svc "$BACKEND" -n "$NS" -o json 2>/dev/null | jq -e --argjson l "$LABELS" '
    (.spec.selector // {}) | length > 0 and (to_entries | all(. as $e | $l[$e.key] == $e.value))' >/dev/null; then
  echo "❌ The Ingress backend Service does not route to the Pod 'shop-web'"
  exit 1
fi

echo "✅ The Ingress routes bingo.com to Pod 'shop-web' through Service '$BACKEND' with TLS from 'bingo-tls'"
exit 0
