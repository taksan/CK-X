#!/bin/bash
# Item (by behaviour): on node01 the container running the process "cryptominer" is stopped and removed from the
# runtime (no container left for it, no such process), while the other containers of the namespace still run
source "$(dirname "$0")/../lib/nodes.sh"

NS="crypto-watch"

RESULT=$(ssh -o StrictHostKeyChecking=no node01 'bash -s' <<'EOF'
export CONTAINER_RUNTIME_ENDPOINT=unix:///run/containerd/containerd.sock
MINER=$(crictl ps -a --label io.kubernetes.pod.name=batch-runner --label io.kubernetes.pod.namespace=crypto-watch -q 2>/dev/null | wc -l)
PROC=$(pgrep -x cryptominer | wc -l)
RUNNING=0
for p in metrics-agent log-shipper; do
  n=$(crictl ps --state running --label io.kubernetes.pod.name=$p --label io.kubernetes.pod.namespace=crypto-watch -q 2>/dev/null | wc -l)
  [ "$n" -ge 1 ] && RUNNING=$((RUNNING + 1))
done
echo "$MINER $PROC $RUNNING"
EOF
)
set -- $RESULT
[ -n "$1" ] || { echo "❌ Unable to query the container runtime of $NODE01"; exit 1; }
[ "$2" = "0" ] || { echo "❌ A process called cryptominer still runs on $NODE01"; exit 1; }
[ "$1" = "0" ] || { echo "❌ The container of the miner still exists in the runtime of $NODE01 (it must be stopped AND removed: crictl stop, crictl rm)"; exit 1; }
[ "$3" = "2" ] || { echo "❌ Only $3 of the 2 ordinary containers of $NS (metrics-agent, log-shipper) still run: only the miner had to be removed"; exit 1; }

echo "✅ The miner container is gone and the other containers still run"
exit 0
