#!/bin/bash
# Source this file (question 9): finds the issued certificate of the CSR of john
#   find_john_csr   sets CSR_NAME to the first CSR whose request has CN=john ("" when none) and CSR_JSON
find_john_csr() {
  CSR_NAME=""; CSR_JSON=""
  local csr subject
  for csr in $(kubectl get csr -o name 2>/dev/null); do
    subject=$(kubectl get "$csr" -o jsonpath='{.spec.request}' 2>/dev/null | base64 -d 2>/dev/null | openssl req -noout -subject 2>/dev/null)
    if echo "$subject" | grep -Eq 'CN ?= ?john'; then
      CSR_NAME="$csr"; CSR_JSON=$(kubectl get "$csr" -o json); return 0
    fi
  done
  return 1
}
