#!/bin/bash
# Item: the signed certificate of john was fetched and saved to /tmp/exam/mhagou-009-q9/john.crt

source "$(dirname "$0")/../lib/csr-john.sh"
FILE="${Q9_FILE:-/tmp/exam/mhagou-009-q9/john.crt}"
find_john_csr || { echo "❌ No CertificateSigningRequest for the user john (CN=john) found"; exit 1; }

ISSUED=$(echo "$CSR_JSON" | jq -r '.status.certificate // empty' | base64 -d 2>/dev/null)
[ -n "$ISSUED" ] || { echo "❌ $CSR_NAME has no issued certificate (approve it first)"; exit 1; }
echo "$ISSUED" | openssl x509 -noout -subject 2>/dev/null | grep -Eq 'CN ?= ?john' || { echo "❌ The issued certificate is not for CN=john"; exit 1; }
echo "$ISSUED" | openssl x509 -noout -checkend 0 >/dev/null 2>&1 || { echo "❌ The issued certificate is expired"; exit 1; }
[ "$(echo "$CSR_JSON" | jq -r '.spec.request' | base64 -d | openssl req -noout -pubkey 2>/dev/null)" = "$(echo "$ISSUED" | openssl x509 -noout -pubkey 2>/dev/null)" ] \
  || { echo "❌ The issued certificate is not for the key of the request"; exit 1; }

[ -s "$FILE" ] || { echo "❌ $FILE does not exist or is empty: save the signed certificate there"; exit 1; }
F1=$(openssl x509 -in "$FILE" -noout -fingerprint -sha256 2>/dev/null || openssl x509 -inform DER -in "$FILE" -noout -fingerprint -sha256 2>/dev/null)
F2=$(echo "$ISSUED" | openssl x509 -noout -fingerprint -sha256 2>/dev/null)
[ -n "$F1" ] && [ "$F1" = "$F2" ] || { echo "❌ $FILE is not the certificate issued by the cluster for john"; exit 1; }

echo "✅ The signed certificate of john is saved in $FILE"
exit 0
