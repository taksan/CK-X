#!/bin/bash

# Setup for MHagou-006 Question 3: TLS Ingress for a backend that lives in another namespace.
# Namespaces asia, europe and world are exclusive to this question and start empty. The setup only
# generates the certificate and key that the candidate has to use (self-signed for the host
# world.universe.mine) in /tmp/exam/mhagou-006-q3 on the jumphost.

source "$(dirname "$0")/../lib/wait-cluster.sh"

DIR="/tmp/exam/mhagou-006-q3"
for ns in asia europe world; do
  ensure_namespace "$ns"
done

mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*
openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj "/CN=world.universe.mine" \
  -addext "subjectAltName=DNS:world.universe.mine" \
  -keyout "$DIR/cert.key" -out "$DIR/cert.crt" >/dev/null 2>&1
[ -s "$DIR/cert.crt" ] || { echo "WARNING: unable to create the certificate"; exit 1; }

source "$(dirname "$0")/../lib/ingress-address.sh"
add_ingress_host world.universe.mine   # the candidate can curl the host directly

echo "Setup completed for MHagou-006 Question 3 (namespaces asia, europe, world; files in $DIR)"
exit 0
