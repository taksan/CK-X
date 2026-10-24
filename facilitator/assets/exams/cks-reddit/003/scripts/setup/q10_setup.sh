#!/bin/bash

# Setup for CKS-003 Question 10: an Ingress with TLS. Namespace web-tls is exclusive to this
# question. A certificate for bingo.com is generated on every run and left in the working
# directory. (An ingress controller must be installed on the cluster: cluster preparation.)

source "$(dirname "$0")/../lib/wait-cluster.sh"

NAMESPACE="web-tls"
WORKDIR="/tmp/exam/cks-003-q10"

ensure_namespace "$NAMESPACE"

mkdir -p "${WORKDIR:?}"
rm -f "${WORKDIR:?}"/*
openssl req -x509 -nodes -newkey rsa:2048 -days 30 -subj "/CN=bingo.com" \
  -addext "subjectAltName=DNS:bingo.com" \
  -keyout "$WORKDIR/bingo.key" -out "$WORKDIR/bingo.crt" >/dev/null 2>&1

source "$(dirname "$0")/../lib/ingress-address.sh"
add_ingress_host bingo.com   # the candidate can curl the host directly

echo "Setup completed for CKS-003 Question 10 (namespace '$NAMESPACE', certificate in $WORKDIR)"
exit 0
