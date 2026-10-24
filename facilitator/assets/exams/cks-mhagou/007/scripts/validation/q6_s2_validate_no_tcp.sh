#!/bin/bash
# Item: the daemon does not accept external TCP connections (credited only when the service runs)

source "$(dirname "$0")/../lib/dockerd-lab.sh"
source "$(dirname "$0")/../lib/nodes.sh"
dockerd_lab_state "" || { echo "❌ Unable to read the state of dockerd-lab on $NODE01"; exit 1; }
[ "$DL_RUN" = "yes" ] || { echo "❌ dockerd-lab.service does not run stably on $NODE01: it must keep running without the TCP listener (journalctl -u dockerd-lab)"; exit 1; }
[ "$DL_SOCK" = "sock" ] || { echo "❌ The unix socket /run/dockerd-lab.sock does not exist: the daemon must keep its local socket"; exit 1; }
[ "$DL_TCP" = "0" ] || { echo "❌ $NODE01 still listens on TCP port 2375"; exit 1; }

IP=$(kubectl get node "$NODE01" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
if curl -s -m 4 "http://$IP:2375/_ping" 2>/dev/null | grep -q OK; then
  echo "❌ http://$IP:2375/_ping still answers"
  exit 1
fi

echo "✅ dockerd-lab has no TCP listener (only its unix socket)"
exit 0
