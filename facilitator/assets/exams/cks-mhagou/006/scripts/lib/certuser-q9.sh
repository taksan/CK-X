#!/bin/bash
# Source this file: find_user_context looks in the kubeconfig of the candidate for a user whose client
# certificate has the CN 60099@internal.users and sets Q9_USER (kubeconfig user name), Q9_CERT (PEM
# file), Q9_KEY (PEM file), Q9_CTX (a context that uses it). The temporary files are removed on exit.

Q9_WANT="60099@internal.users"
Q9_TMP=$(mktemp -d)
trap 'rm -rf "$Q9_TMP"' EXIT

find_user_context() {
  local cfg name cdata cpath kdata kpath
  cfg=$(kubectl config view --raw -o json 2>/dev/null)
  [ -n "$cfg" ] || return 1
  while IFS='|' read -r name cdata cpath kdata kpath; do
    [ -n "$name" ] || continue
    if [ -n "$cdata" ]; then echo "$cdata" | base64 -d > "$Q9_TMP/cert.pem" 2>/dev/null
    elif [ -n "$cpath" ] && [ -f "$cpath" ]; then cp "$cpath" "$Q9_TMP/cert.pem"
    else continue; fi
    if openssl x509 -in "$Q9_TMP/cert.pem" -noout -subject 2>/dev/null | grep -Eq "CN ?= ?$Q9_WANT"; then
      if [ -n "$kdata" ]; then echo "$kdata" | base64 -d > "$Q9_TMP/key.pem" 2>/dev/null
      elif [ -n "$kpath" ] && [ -f "$kpath" ]; then cp "$kpath" "$Q9_TMP/key.pem"
      else : > "$Q9_TMP/key.pem"; fi
      Q9_USER="$name"; Q9_CERT="$Q9_TMP/cert.pem"; Q9_KEY="$Q9_TMP/key.pem"
      Q9_CTX=$(echo "$cfg" | jq -r --arg n "$name" '[.contexts[]? | select(.context.user == $n) | .name] | first // empty')
      return 0
    fi
  done < <(echo "$cfg" | jq -r '.users[]? | [.name, (.user["client-certificate-data"] // ""), (.user["client-certificate"] // ""), (.user["client-key-data"] // ""), (.user["client-key"] // "")] | join("|")')
  return 1
}
