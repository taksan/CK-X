#!/bin/bash
# Item: a valid CertificateSigningRequest for the user john (CN=john, client signer)

source "$(dirname "$0")/../lib/csr-john.sh"
find_john_csr || { echo "❌ No CertificateSigningRequest for the user john (CN=john) found"; exit 1; }

[ "$(echo "$CSR_JSON" | jq -r '.spec.signerName')" = "kubernetes.io/kube-apiserver-client" ] \
  || { echo "❌ $CSR_NAME does not use the signer kubernetes.io/kube-apiserver-client"; exit 1; }
echo "$CSR_JSON" | jq -r '.spec.request' | base64 -d | openssl req -noout -verify >/dev/null 2>&1 \
  || { echo "❌ The request of $CSR_NAME has an invalid signature"; exit 1; }
echo "$CSR_JSON" | jq -e '(.spec.usages // []) | index("client auth") != null' >/dev/null \
  || { echo "❌ $CSR_NAME does not request the usage 'client auth'"; exit 1; }

echo "✅ $CSR_NAME requests a client certificate for CN=john"
exit 0
