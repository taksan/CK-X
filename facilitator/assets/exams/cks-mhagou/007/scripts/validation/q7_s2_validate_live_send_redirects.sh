#!/bin/bash
# Item: the running kernel of node02 does not send ICMP redirects on new interfaces
source "$(dirname "$0")/../lib/nodes.sh"

V=$(ssh -o StrictHostKeyChecking=no node02 'sysctl -n net.ipv4.conf.default.send_redirects' 2>/dev/null)
[ "$V" = "0" ] || { echo "❌ net.ipv4.conf.default.send_redirects is '${V:-unknown}' on $NODE02, expected 0"; exit 1; }

echo "✅ net.ipv4.conf.default.send_redirects = 0 on $NODE02 (live)"
exit 0
