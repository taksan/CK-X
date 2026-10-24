#!/bin/bash
# Helpers of the validators of question 2 (source with: source "$(dirname "$0")/../lib/q2-lib.sh").
#
#   find_tls_host     looks for an Ingress of secure-ingress with a TLS entry for a host that the SAME
#                     Ingress also routes, whose Secret (type kubernetes.io/tls) holds an unexpired
#                     certificate valid for that host and its matching private key.
#                     Sets TLS_HOST, TLS_SECRET and TLS_CERT (path of the PEM, in a temp dir) and returns 0;
#                     otherwise prints the first problem found and returns 1.

NS="secure-ingress"
TLS_WORK=""

find_tls_host() {
  local J i n host secret t crt key problem=""
  J=$(kubectl get ingress -n "$NS" -o json 2>/dev/null)
  if [ -z "$J" ] || [ "$(echo "$J" | jq '.items | length')" = "0" ]; then
    echo "❌ There is no Ingress in the namespace $NS"
    return 1
  fi
  TLS_WORK=$(mktemp -d)
  trap 'rm -rf "$TLS_WORK"' EXIT

  # every (ingress, host, secret) combination where the host is routed by the same Ingress
  while IFS=$'\t' read -r ing host secret; do
    [ -n "$host" ] || continue
    t=$(kubectl get secret "$secret" -n "$NS" -o jsonpath='{.type}' 2>/dev/null)
    if [ "$t" != "kubernetes.io/tls" ]; then
      problem="${problem:-❌ Ingress $ing: the Secret '$secret' referenced for $host does not exist or is not of type kubernetes.io/tls}"
      continue
    fi
    crt="$TLS_WORK/$secret.crt"; key="$TLS_WORK/$secret.key"
    kubectl get secret "$secret" -n "$NS" -o jsonpath='{.data.tls\.crt}' | base64 -d > "$crt" 2>/dev/null
    kubectl get secret "$secret" -n "$NS" -o jsonpath='{.data.tls\.key}' | base64 -d > "$key" 2>/dev/null
    if ! openssl x509 -in "$crt" -noout >/dev/null 2>&1; then
      problem="${problem:-❌ The Secret '$secret' does not contain a valid certificate}"; continue
    fi
    if ! openssl x509 -in "$crt" -noout -checkend 0 >/dev/null 2>&1; then
      problem="${problem:-❌ The certificate of the Secret '$secret' is expired}"; continue
    fi
    if ! openssl x509 -in "$crt" -noout -checkhost "$host" 2>/dev/null | grep -q 'does match'; then
      problem="${problem:-❌ The certificate of the Secret '$secret' is not valid for the host $host of the Ingress $ing}"; continue
    fi
    if [ "$(openssl x509 -in "$crt" -noout -pubkey 2>/dev/null | openssl sha256 2>/dev/null)" != "$(openssl pkey -in "$key" -pubout 2>/dev/null | openssl sha256 2>/dev/null)" ]; then
      problem="${problem:-❌ The private key of the Secret '$secret' does not match its certificate}"; continue
    fi
    TLS_HOST="$host"; TLS_SECRET="$secret"; TLS_CERT="$crt"
    return 0
  done < <(echo "$J" | jq -r '.items[] | .metadata.name as $n | [.spec.rules[]?.host] as $routed
      | .spec.tls[]? | .secretName as $s | .hosts[]? | select(. as $h | $routed | index($h)) | [$n, ., $s] | @tsv')

  if [ -z "$problem" ]; then
    problem="❌ No Ingress configures TLS (spec.tls with hosts and a secretName) for a host that the same Ingress routes"
  fi
  echo "$problem"
  return 1
}
