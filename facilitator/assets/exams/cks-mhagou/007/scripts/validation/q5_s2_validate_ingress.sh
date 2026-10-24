#!/bin/bash
# Item: Ingress rocket-ingress (class traefik, host rocket-server.local, path / Prefix, backend rocket-server:80, TLS secret-tls)

J=$(kubectl get ingress rocket-ingress -n rocket -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Ingress 'rocket-ingress' not found in namespace 'rocket'"; exit 1; }

[ "$(echo "$J" | jq -r '.spec.ingressClassName // ""')" = "traefik" ] || { echo "❌ The Ingress class must be traefik"; exit 1; }
echo "$J" | jq -e '[.spec.rules[]? | select(.host == "rocket-server.local") | .http.paths[]?
  | select(.path == "/" and .pathType == "Prefix" and .backend.service.name == "rocket-server" and .backend.service.port.number == 80)] | length > 0' >/dev/null \
  || { echo "❌ No rule routes host rocket-server.local, path / (Prefix) to Service rocket-server on port 80"; exit 1; }
echo "$J" | jq -e '[.spec.tls[]? | select(.secretName == "secret-tls" and ((.hosts // []) | index("rocket-server.local") != null))] | length > 0' >/dev/null \
  || { echo "❌ The Ingress has no tls entry with secretName secret-tls for the host rocket-server.local"; exit 1; }

echo "✅ rocket-ingress routes rocket-server.local to rocket-server:80 with TLS from secret-tls"
exit 0
