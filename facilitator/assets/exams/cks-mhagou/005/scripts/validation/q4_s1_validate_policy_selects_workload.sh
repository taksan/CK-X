#!/bin/bash
# A NetworkPolicy of metadata-protect restricts the egress of the Pod metadata-client

source "$(dirname "$0")/../lib/netpol_checks.sh"
NS="metadata-protect"
load_netpol "$NS" metadata-client || exit 1

if [ "$(jq '.items | length' "$NETPOL_WORK/policies.json")" = "0" ]; then
  echo "❌ There is no NetworkPolicy in the namespace $NS"
  exit 1
fi

# a Pod without egress restriction is allowed everywhere, even on a port nobody would open on purpose
egress_allowed 8.8.8.8 65000 TCP
case "$EGRESS_REASON" in
  "no policy restricts"*) echo "❌ No NetworkPolicy restricts the egress of the Pod metadata-client (policyTypes must include Egress and the podSelector must select app=metadata-client)"; exit 1 ;;
esac

echo "✅ The egress of the Pod metadata-client is restricted by a NetworkPolicy"
exit 0
