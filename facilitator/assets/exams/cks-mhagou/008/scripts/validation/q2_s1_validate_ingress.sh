#!/bin/bash
# Item: Ingress secure-ingress of the class traefik routes secure-app.company.com / to Service
# secure-app and terminates TLS with the Secret web-tls

NS="secure-web"
HOST="secure-app.company.com"

J=$(kubectl get ingress secure-ingress -n "$NS" -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Ingress 'secure-ingress' not found in namespace '$NS'"; exit 1; }

CLASS=$(echo "$J" | jq -r '.spec.ingressClassName // .metadata.annotations["kubernetes.io/ingress.class"] // ""')
if [ "$CLASS" != "traefik" ]; then
  echo "❌ The Ingress class is '${CLASS:-none}', expected traefik (the controller installed in the cluster)"
  exit 1
fi

SVC=$(kubectl get svc secure-app -n "$NS" -o json 2>/dev/null)
echo "$J" | jq -e --argjson svc "${SVC:-null}" --arg h "$HOST" '
  any(.spec.rules[]?; .host == $h and any(.http.paths[]?; .path == "/" and .backend.service.name == "secure-app"
    and (.backend.service.port as $p | any($svc.spec.ports[]?; ($p.number != null and .port == $p.number) or ($p.name != null and .name == $p.name)))))' >/dev/null \
  || { echo "❌ No rule routes host $HOST, path / to a valid port of Service secure-app"; exit 1; }

echo "$J" | jq -e --arg h "$HOST" 'any(.spec.tls[]?; .secretName == "web-tls" and any(.hosts[]?; . == $h))' >/dev/null \
  || { echo "❌ The TLS section does not use the Secret web-tls for $HOST"; exit 1; }

echo "✅ secure-ingress routes $HOST to secure-app (class traefik) with TLS from web-tls"
exit 0
