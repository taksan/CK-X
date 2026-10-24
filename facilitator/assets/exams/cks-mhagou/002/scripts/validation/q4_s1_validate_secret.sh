#!/bin/bash
# Secret secret1 in secret-lab has user=admin and pass=P455W0RD

NS="secret-lab"
U=$(kubectl get secret secret1 -n "$NS" -o jsonpath='{.data.user}' 2>/dev/null | base64 -d 2>/dev/null)
P=$(kubectl get secret secret1 -n "$NS" -o jsonpath='{.data.pass}' 2>/dev/null | base64 -d 2>/dev/null)
[ -n "$U$P" ] || { echo "❌ Secret 'secret1' (keys user and pass) not found in namespace '$NS'"; exit 1; }
if [ "$U" != "admin" ] || [ "$P" != "P455W0RD" ]; then
  echo "❌ Secret 'secret1' must have user=admin and pass=P455W0RD (found user='$U', pass='$P')"
  exit 1
fi
echo "✅ Secret secret1 has the requested keys and values"
exit 0
