#!/bin/bash
# An Ingress of secure-ingress has an HTTP host rule that routes to the Service web-service on port 80

NS="secure-ingress"
J=$(kubectl get ingress -n "$NS" -o json 2>/dev/null)
if [ -z "$J" ] || [ "$(echo "$J" | jq '.items | length')" = "0" ]; then
  echo "❌ There is no Ingress in the namespace $NS"
  exit 1
fi

echo "$J" | jq -e 'any(.items[]; any(.spec.rules[]?; (.host // "") != "" and any(.http.paths[]?; .backend.service.name == "web-service" and (.backend.service.port.number == 80 or .backend.service.port.name == "http"))))' >/dev/null \
  || { echo "❌ No Ingress has a host rule that routes to the Service web-service on port 80"; exit 1; }

echo "✅ An Ingress routes a host to the Service web-service on port 80"
exit 0
