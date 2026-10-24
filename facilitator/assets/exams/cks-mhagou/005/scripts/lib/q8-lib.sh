#!/bin/bash
# Helpers of the validators of question 8 (source with: source "$(dirname "$0")/../lib/q8-lib.sh").
#   init_q8               finds the API addresses: CLUSTER_URL (Service ClusterIP) and ENDPOINT_URLS
#   api_code POD URL      HTTP status of the request from the Pod (000 when the connection fails)
#   restricted_blocked    0 when restricted-pod cannot reach the API through the ClusterIP and the endpoints
#                         (the first probe polls up to 18 s: the policy needs a few seconds to be enforced)

NS="api-restrict"

init_q8() {
  local ip port eps
  ip=$(kubectl get service kubernetes -n default -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
  port=$(kubectl get service kubernetes -n default -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
  [ -n "$ip" ] && [ -n "$port" ] || { echo "❌ Unable to find the Service kubernetes"; return 1; }
  CLUSTER_URL="https://$ip:$port/version"
  ENDPOINT_URLS=""
  eps=$(kubectl get endpointslice -n default -l kubernetes.io/service-name=kubernetes -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{"\n"}{end}{end}' 2>/dev/null)
  port=$(kubectl get endpointslice -n default -l kubernetes.io/service-name=kubernetes -o jsonpath='{.items[0].ports[0].port}' 2>/dev/null)
  for a in $eps; do
    ENDPOINT_URLS="$ENDPOINT_URLS https://$a:$port/version"
  done
  for p in admin-pod restricted-pod; do
    kubectl get pod "$p" -n "$NS" >/dev/null 2>&1 || { echo "❌ The Pod $p was deleted: the existing test Pods must not be deleted or recreated"; return 1; }
  done
}

api_code() {
  # curl prints 000 itself when the connection fails (and exits non-zero): keep only the status
  local c
  c=$(kubectl exec -n "$NS" "$1" -- curl -ks --connect-timeout 3 --max-time 6 -o /dev/null -w '%{http_code}' "$2" 2>/dev/null)
  c=${c:0:3}
  [ -n "$c" ] || c=000
  echo "$c"
}

restricted_blocked() {
  local i url
  for i in $(seq 1 6); do
    [ "$(api_code restricted-pod "$CLUSTER_URL")" = "000" ] && break
    sleep 3
  done
  if [ "$(api_code restricted-pod "$CLUSTER_URL")" != "000" ]; then
    BLOCK_REASON="restricted-pod can still reach the Kubernetes API through the Service address ($CLUSTER_URL)"
    return 1
  fi
  for url in $ENDPOINT_URLS; do
    if [ "$(api_code restricted-pod "$url")" != "000" ]; then
      BLOCK_REASON="restricted-pod can still reach the API server through its real address ($url, see kubectl get endpoints kubernetes)"
      return 1
    fi
  done
  return 0
}
