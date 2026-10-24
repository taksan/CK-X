#!/bin/bash
# Validate a CertificateSigningRequest for the user john (CN=john) was approved and signed.
# The CSR can have any name: it is found by the subject of its request.

FOUND=""
for csr in $(kubectl get csr -o name 2>/dev/null); do
  SUBJECT=$(kubectl get "$csr" -o jsonpath='{.spec.request}' 2>/dev/null | base64 -d 2>/dev/null | openssl req -noout -subject 2>/dev/null)
  if echo "$SUBJECT" | grep -Eq 'CN ?= ?john'; then
    FOUND="$csr"
    break
  fi
done

if [ -z "$FOUND" ]; then
  echo "❌ No CertificateSigningRequest for the user john (CN=john) found"
  exit 1
fi

JSON=$(kubectl get "$FOUND" -o json)

if [ "$(echo "$JSON" | jq -r '.spec.signerName')" != "kubernetes.io/kube-apiserver-client" ]; then
  echo "❌ $FOUND does not use the signer kubernetes.io/kube-apiserver-client"
  exit 1
fi

if ! echo "$JSON" | jq -e '[.status.conditions[]? | select(.type == "Approved" and .status == "True")] | length > 0' >/dev/null; then
  echo "❌ $FOUND is not approved"
  exit 1
fi

CERT=$(echo "$JSON" | jq -r '.status.certificate // empty')
if [ -z "$CERT" ]; then
  echo "❌ $FOUND has no signed certificate yet"
  exit 1
fi

if ! echo "$CERT" | base64 -d | openssl x509 -noout -subject 2>/dev/null | grep -Eq 'CN ?= ?john'; then
  echo "❌ The signed certificate is not for CN=john"
  exit 1
fi

echo "✅ $FOUND is approved and the signed certificate is for CN=john"
exit 0
