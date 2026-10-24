#!/bin/bash
# Item: the CSR of john was approved (not denied or failed)

source "$(dirname "$0")/../lib/csr-john.sh"
find_john_csr || { echo "❌ No CertificateSigningRequest for the user john (CN=john) found"; exit 1; }

C=$(echo "$CSR_JSON" | jq -r '[.status.conditions[]? | "\(.type)=\(.status)"] | join(" ")')
case "$C" in
  *Denied=True*|*Failed=True*) echo "❌ $CSR_NAME was denied or failed ($C)"; exit 1 ;;
  *Approved=True*) ;;
  *) echo "❌ $CSR_NAME is not approved (conditions: ${C:-none})"; exit 1 ;;
esac

echo "✅ $CSR_NAME is approved"
exit 0
