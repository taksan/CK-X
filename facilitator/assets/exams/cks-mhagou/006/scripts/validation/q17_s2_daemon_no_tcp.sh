#!/bin/bash
# The daemon does not listen on TCP any more (port 2375) while the service runs and still serves its
# unix socket (the service was reconfigured, not stopped)

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$NODE02"
R=$(ssh -o StrictHostKeyChecking=no "$NODE" 'systemctl is-active lab-docker.service; ss -ltn | grep -c ":2375 "; test -S /var/run/lab-docker.sock && echo sock-ok; systemctl cat lab-docker.service 2>/dev/null | grep -c "tcp://"' 2>/dev/null)

[ "$(echo "$R" | sed -n 2p)" = "0" ] || { echo "❌ The daemon still listens on TCP port 2375 of $NODE (was the unit edited, daemon-reload run and the service restarted?)"; exit 1; }
[ "$(echo "$R" | sed -n 1p)" = "active" ] || { echo "❌ The service lab-docker is not running: it must be reconfigured, not stopped"; exit 1; }
echo "$R" | grep -q sock-ok || { echo "❌ The unix socket of the daemon is gone: only the TCP listener had to be removed"; exit 1; }
[ "$(echo "$R" | tail -1)" = "0" ] || { echo "❌ The unit file still contains a tcp:// host"; exit 1; }

echo "✅ The daemon no longer listens on TCP and still serves its unix socket"
exit 0
