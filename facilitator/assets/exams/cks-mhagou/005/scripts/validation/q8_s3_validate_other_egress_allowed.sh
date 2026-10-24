#!/bin/bash
# Other egress stays allowed for both Pods (external addresses, any port: evaluated with the
# NetworkPolicy semantics), credited only when the API is blocked for restricted-pod

source "$(dirname "$0")/../lib/q8-lib.sh"
source "$(dirname "$0")/../lib/netpol_checks.sh"
init_q8 || exit 1
restricted_blocked || { echo "❌ $BLOCK_REASON (nothing to credit yet)"; exit 1; }

for pod in restricted-pod admin-pod; do
  load_netpol "$NS" "$pod" || exit 1
  for ip in 8.8.8.8 1.1.1.1 142.250.1.1 10.20.30.40; do
    for spec in "TCP 443" "TCP 80" "UDP 53" "TCP 8080"; do
      read -r proto port <<< "$spec"
      if ! egress_allowed "$ip" "$port" "$proto"; then
        echo "❌ Egress of $pod to $ip:$port/$proto is denied: only the API access had to be restricted ($EGRESS_REASON)"
        exit 1
      fi
    done
  done
done

echo "✅ Other egress is still allowed for both Pods; only the API access of restricted-pod is blocked"
exit 0
