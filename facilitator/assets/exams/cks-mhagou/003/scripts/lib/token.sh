#!/bin/bash
# Source this file (question 10): helpers to read the projected tokens of the Pod token-pod

TOKEN_NS="token-lab"
TOKEN_POD="token-pod"
TOKEN_DIR="/var/run/secrets/custom-tokens"

# projected_sources KIND: JSON list of the sources of KIND (secret|serviceAccountToken) of the projected
# volumes that are mounted at TOKEN_DIR
projected_sources() {
  kubectl get pod "$TOKEN_POD" -n "$TOKEN_NS" -o json 2>/dev/null | jq -c --arg k "$1" --arg d "$TOKEN_DIR" '
    . as $p | [ $p.spec.containers[]?.volumeMounts[]? | select(.mountPath == $d) | .name ] as $names
    | [ $p.spec.volumes[]? | select(.name as $n | $names | index($n)) | select(.projected != null)
        | .projected.sources[]? | select(.[$k] != null) | .[$k] ]'
}

# read_in_pod PATH
read_in_pod() { kubectl exec -n "$TOKEN_NS" "$TOKEN_POD" -- cat "$1" 2>/dev/null; }

# jwt_claims TOKEN: JSON claims
jwt_claims() {
  local p; p=$(echo "$1" | cut -d. -f2 | tr '_-' '/+')
  while [ $(( ${#p} % 4 )) -ne 0 ]; do p="${p}="; done
  echo "$p" | base64 -d 2>/dev/null
}

# token_user TOKEN: the username that the API server authenticates for TOKEN ("" when rejected)
token_user() {
  local aud
  aud=$(jwt_claims "$1" | jq -c '.aud // []' 2>/dev/null)
  kubectl create -o json -f - 2>/dev/null <<EOF | jq -r 'select(.status.authenticated == true) | .status.user.username'
apiVersion: authentication.k8s.io/v1
kind: TokenReview
spec:
  token: "$1"
  audiences: ${aud:-[]}
EOF
}
