#!/bin/bash
# The metadata address 169.254.169.254 is denied (several ports, TCP and UDP) for metadata-client

source "$(dirname "$0")/../lib/netpol_checks.sh"
load_netpol metadata-protect metadata-client || exit 1

for spec in "TCP 80" "TCP 443" "TCP 8080" "UDP 53" "TCP 53"; do
  read -r proto port <<< "$spec"
  if egress_allowed 169.254.169.254 "$port" "$proto"; then
    echo "❌ Egress to 169.254.169.254:$port/$proto is still allowed ($EGRESS_REASON)"
    exit 1
  fi
done

echo "✅ Egress to the metadata address 169.254.169.254 is denied"
exit 0
