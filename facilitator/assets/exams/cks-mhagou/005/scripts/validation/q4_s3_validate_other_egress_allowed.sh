#!/bin/bash
# Everything else stays reachable (addresses next to the metadata one, public and private addresses),
# credited only when the metadata address is blocked

source "$(dirname "$0")/../lib/netpol_checks.sh"
load_netpol metadata-protect metadata-client || exit 1

if egress_allowed 169.254.169.254 80 TCP; then
  echo "❌ The metadata address is not blocked yet: nothing to credit"
  exit 1
fi
for ip in 169.254.169.253 169.254.169.255 8.8.8.8 1.1.1.1 10.20.30.40 172.16.5.5 192.168.1.1; do
  for spec in "TCP 80" "TCP 443" "UDP 53"; do
    read -r proto port <<< "$spec"
    if ! egress_allowed "$ip" "$port" "$proto"; then
      echo "❌ Egress to $ip:$port/$proto is denied: only 169.254.169.254 had to be blocked ($EGRESS_REASON)"
      exit 1
    fi
  done
done

echo "✅ Only the metadata address is blocked; all other egress is still allowed"
exit 0
