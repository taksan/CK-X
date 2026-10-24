#!/bin/bash
# Item: the Docker daemon listens on no TCP port, still answers on its socket, and the cluster is healthy

source "$(dirname "$0")/../lib/nodes.sh"

NODE="$NODE02"
R=$(ssh -o StrictHostKeyChecking=no "$NODE" 'T=$(ss -ltnp 2>/dev/null | grep -c "dockerd"); P=$(curl -s -m 5 --unix-socket /var/run/docker.sock http://localhost/_ping 2>/dev/null); echo "$T|$P"' 2>/dev/null)
T="${R%%|*}"; P="${R#*|}"

if [ "${T:-0}" != "0" ]; then
  echo "❌ The Docker daemon still listens on a TCP port on $NODE"
  exit 1
fi
[ "$P" = "OK" ] || { echo "❌ The Docker daemon is not running or does not answer on its Unix socket"; exit 1; }

NOTREADY=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2 != "Ready"' | head -1)
[ -z "$NOTREADY" ] || { echo "❌ A node is not Ready: $NOTREADY"; exit 1; }
BAD=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | awk '$3 != "Running" && $3 != "Completed"' | head -1)
[ -z "$BAD" ] || { echo "❌ A kube-system Pod is not healthy: $BAD"; exit 1; }

echo "✅ The Docker daemon listens on no TCP port and the cluster is healthy"
exit 0
