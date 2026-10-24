#!/bin/bash

# Setup for CKS-004 Question 9: Secrets. Namespaces dev and app are exclusive to this question.
# The secret "platform-certs" in dev holds a CA certificate generated on every run.

source "$(dirname "$0")/../lib/wait-cluster.sh"

WORKDIR="/tmp/exam/cks-004-q9"

ensure_namespace dev
ensure_namespace app

kubectl delete secret platform-certs -n dev --ignore-not-found >/dev/null 2>&1
kubectl delete secret app-config-secret -n app --ignore-not-found >/dev/null 2>&1
kubectl delete pod app-pod -n app --ignore-not-found --now >/dev/null 2>&1

mkdir -p "${WORKDIR:?}"
rm -f "${WORKDIR:?}"/*
openssl req -x509 -nodes -newkey rsa:2048 -days 30 -subj "/CN=platform-ca-$RANDOM" \
  -keyout "$WORKDIR/.ca.key" -out "$WORKDIR/.ca.crt" >/dev/null 2>&1
kubectl create secret generic platform-certs -n dev \
  --from-file=ca.crt="$WORKDIR/.ca.crt" --from-literal=region=eu-west >/dev/null
rm -f "$WORKDIR/.ca.key" "$WORKDIR/.ca.crt"

echo "Setup completed for CKS-004 Question 9 (namespaces dev and app, output directory $WORKDIR)"
exit 0
