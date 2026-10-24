#!/bin/bash
# Item: https://secure-app.company.com/ answers with the page of the application
# (checked through the address of the ingress controller)

source "$(dirname "$0")/../lib/ingress-address.sh"
if [ -z "$INGRESS_IP" ] || [ -z "$INGRESS_HTTPS" ]; then
  echo "❌ The ingress controller is not reachable"
  exit 1
fi

for i in $(seq 1 15); do
  BODY=$(curl -sk -m 5 --resolve "secure-app.company.com:$INGRESS_HTTPS:$INGRESS_IP" "https://secure-app.company.com:$INGRESS_HTTPS/" 2>/dev/null)
  echo "$BODY" | grep -q 'MHagou secure-app' && break
  sleep 3
done

if ! echo "$BODY" | grep -q 'MHagou secure-app'; then
  echo "❌ https://secure-app.company.com/ does not return the page of secure-app (got: $(echo "$BODY" | head -c 60))"
  exit 1
fi

echo "✅ https://secure-app.company.com/ returns the page of secure-app"
exit 0
