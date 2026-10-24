#!/bin/bash
# Validate Pod shop-web runs and a Service on port 80 routes to it

NS="web-tls"

POD=$(kubectl get pod shop-web -n "$NS" -o json 2>/dev/null)
if [ -z "$POD" ]; then
  echo "❌ Pod 'shop-web' not found in namespace '$NS'"
  exit 1
fi

if [ "$(echo "$POD" | jq -r '.status.phase')" != "Running" ]; then
  echo "❌ Pod 'shop-web' is not running"
  exit 1
fi

# a Service whose selector matches the Pod and which has a ready endpoint
SVC=$(kubectl get svc -n "$NS" -o json | jq -r --argjson l "$(echo "$POD" | jq -c '.metadata.labels // {}')" '
  .items[] | select((.spec.selector // {}) | length > 0)
  | select(.spec.selector | to_entries | all(. as $e | $l[$e.key] == $e.value))
  | select([.spec.ports[]? | select(.port == 80)] | length > 0) | .metadata.name' | head -1)

if [ -z "$SVC" ]; then
  echo "❌ No Service on port 80 selects the Pod 'shop-web'"
  exit 1
fi

if [ "$(kubectl get endpoints "$SVC" -n "$NS" -o json 2>/dev/null | jq '[.subsets[]?.addresses[]?] | length')" = "0" ]; then
  echo "❌ Service '$SVC' has no ready endpoint"
  exit 1
fi

echo "✅ Pod 'shop-web' is running and Service '$SVC' routes port 80 to it"
exit 0
