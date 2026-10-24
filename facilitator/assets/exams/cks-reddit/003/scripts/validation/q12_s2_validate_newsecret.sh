#!/bin/bash
# Validate secret newsecret in namespace safe

NS="safe"

U=$(kubectl get secret newsecret -n "$NS" -o jsonpath='{.data.username}' 2>/dev/null | base64 -d)
P=$(kubectl get secret newsecret -n "$NS" -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)

if [ -z "$U$P" ]; then
  echo "❌ Secret 'newsecret' not found in namespace '$NS'"
  exit 1
fi

if [ "$U" != "dbadmin" ] || [ "$P" != "moresecurepas" ]; then
  echo "❌ Secret 'newsecret' does not have username=dbadmin and password=moresecurepas"
  exit 1
fi

echo "✅ Secret 'newsecret' has the requested username and password"
exit 0
