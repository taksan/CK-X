#!/bin/bash
# A CertificateSigningRequest for CN=60099@internal.users, signer kube-apiserver-client, approved and
# with an issued certificate

FOUND=""
for csr in $(kubectl get csr -o name 2>/dev/null); do
  if kubectl get "$csr" -o jsonpath='{.spec.request}' 2>/dev/null | base64 -d 2>/dev/null | openssl req -noout -subject 2>/dev/null | grep -Eq 'CN ?= ?60099@internal.users'; then
    J=$(kubectl get "$csr" -o json)
    SIGNER=$(echo "$J" | jq -r '.spec.signerName')
    APPROVED=$(echo "$J" | jq -r '[.status.conditions[]? | select(.type == "Approved" and .status == "True")] | length')
    CERT=$(echo "$J" | jq -r '.status.certificate // empty')
    if [ "$SIGNER" = "kubernetes.io/kube-apiserver-client" ] && [ "$APPROVED" != "0" ] && [ -n "$CERT" ]; then FOUND="$csr"; break; fi
    FOUND="partial:$csr:$SIGNER:$APPROVED"
  fi
done

case "$FOUND" in
  "") echo "❌ No CertificateSigningRequest with the subject CN=60099@internal.users exists"; exit 1 ;;
  partial:*) echo "❌ The CertificateSigningRequest ($FOUND) is not approved and signed with the signer kubernetes.io/kube-apiserver-client"; exit 1 ;;
esac

echo "✅ The CertificateSigningRequest for 60099@internal.users is approved and signed ($FOUND)"
exit 0
