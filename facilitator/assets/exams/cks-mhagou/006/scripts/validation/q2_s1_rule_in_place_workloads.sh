#!/bin/bash
# A custom Falco rule that mentions /tmp/mem exists on node01 (outside the packaged default rules),
# the Falco service runs and the three workloads are still available

source "$(dirname "$0")/../lib/nodes.sh"

NS="mem-watch"
NODE="$NODE01"

R=$(ssh -o StrictHostKeyChecking=no "$NODE" 'systemctl is-active falco-modern-bpf; grep -l "/tmp/mem" /etc/falco/falco_rules.local.yaml /etc/falco/rules.d/* /etc/falco/falco.yaml 2>/dev/null | head -1' 2>/dev/null)
[ "$(echo "$R" | sed -n 1p)" = "active" ] || { echo "❌ The Falco service (falco-modern-bpf) is not running on $NODE"; exit 1; }
[ -n "$(echo "$R" | sed -n 2p)" ] || { echo "❌ No custom Falco rule file on $NODE mentions /tmp/mem (expected in /etc/falco/falco_rules.local.yaml or /etc/falco/rules.d/)"; exit 1; }

for d in compute-a compute-b compute-c; do
  READY=$(kubectl get deployment "$d" -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "${READY:-0}" -ge 1 ] || { echo "❌ Deployment '$d' is not available: the workloads must not be removed or disrupted"; exit 1; }
done

echo "✅ A custom rule for /tmp/mem is in place, Falco runs and the workloads are available"
exit 0
