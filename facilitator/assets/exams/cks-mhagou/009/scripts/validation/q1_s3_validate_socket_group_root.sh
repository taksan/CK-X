#!/bin/bash
# Item: the restarted Docker daemon serves /var/run/docker.sock with the group root

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$NODE02"
R=$(ssh -o StrictHostKeyChecking=no "$NODE" 'G=$(stat -c %G /var/run/docker.sock 2>/dev/null); P=$(curl -s -m 5 --unix-socket /var/run/docker.sock http://localhost/_ping 2>/dev/null); echo "$G|$P"' 2>/dev/null)
G="${R%%|*}"; P="${R#*|}"

[ -n "$G" ] || { echo "❌ /var/run/docker.sock does not exist on $NODE (is the Docker daemon running?)"; exit 1; }
if [ "$G" != "root" ]; then
  echo "❌ /var/run/docker.sock belongs to the group '$G', expected root (was the daemon restarted after the change?)"
  exit 1
fi
[ "$P" = "OK" ] || { echo "❌ The Docker daemon does not answer on the Unix socket"; exit 1; }

echo "✅ /var/run/docker.sock belongs to the group root and the daemon answers"
exit 0
