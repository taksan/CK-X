#!/bin/bash
# Validate secret app-config-secret in namespace app

U=$(kubectl get secret app-config-secret -n app -o jsonpath='{.data.APP_USER}' 2>/dev/null | base64 -d)
P=$(kubectl get secret app-config-secret -n app -o jsonpath='{.data.APP_PASS}' 2>/dev/null | base64 -d)

[ -n "$U$P" ] || { echo "❌ Secret 'app-config-secret' not found in namespace 'app'"; exit 1; }

if [ "$U" != "appadmin" ] || [ "$P" != "Sup3rS3cret" ]; then
  echo "❌ Secret 'app-config-secret' does not have APP_USER=appadmin and APP_PASS=Sup3rS3cret"
  exit 1
fi

echo "✅ Secret 'app-config-secret' has the requested keys and values"
exit 0
