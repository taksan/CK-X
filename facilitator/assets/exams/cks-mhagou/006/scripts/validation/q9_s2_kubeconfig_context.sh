#!/bin/bash
# The kubeconfig has a user with a client certificate for CN=60099@internal.users (issued by the
# cluster CA, with its matching private key) and a context that uses it with the existing cluster

source "$(dirname "$0")/../lib/certuser-q9.sh"
find_user_context || { echo "❌ No user of the kubeconfig has a client certificate with the CN 60099@internal.users"; exit 1; }

CA=$(kubectl config view --raw -o json | jq -r '.clusters[0].cluster["certificate-authority-data"] // empty' | base64 -d 2>/dev/null)
if [ -n "$CA" ]; then
  echo "$CA" > "$Q9_TMP/ca.pem"
  openssl verify -CAfile "$Q9_TMP/ca.pem" "$Q9_CERT" >/dev/null 2>&1 || { echo "❌ The client certificate was not issued by the cluster CA"; exit 1; }
fi

PUB_C=$(openssl x509 -in "$Q9_CERT" -noout -pubkey 2>/dev/null | sha256sum)
PUB_K=$(openssl pkey -in "$Q9_KEY" -pubout 2>/dev/null | sha256sum)
[ "$PUB_C" = "$PUB_K" ] || { echo "❌ The private key of the kubeconfig user '$Q9_USER' does not match its client certificate"; exit 1; }

[ -n "$Q9_CTX" ] || { echo "❌ No context uses the kubeconfig user '$Q9_USER'"; exit 1; }
CLUSTER=$(kubectl config view -o json | jq -r --arg c "$Q9_CTX" '.contexts[] | select(.name == $c) | .context.cluster')
kubectl config view -o json | jq -e --arg cl "$CLUSTER" '[.clusters[] | select(.name == $cl)] | length == 1' >/dev/null || { echo "❌ The context '$Q9_CTX' refers to a cluster that is not in the kubeconfig"; exit 1; }

echo "✅ The kubeconfig has the user '$Q9_USER' (cluster CA certificate and matching key) in the context '$Q9_CTX'"
exit 0
