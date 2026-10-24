#!/bin/bash

# Setup for MHagou-001 Question 7: a custom Falco rule for reads of /etc/shadow on node01.
# Namespace shadow-watch is exclusive; the Pod report-agent runs on node01 (the validators exec into it).
#
# Falco's default rules already report a read of /etc/shadow ("Read sensitive file untrusted"). With the
# default `rule_matching: first` such a default rule would hide a new custom rule, whatever its content
# (the custom file is loaded after the default one). So on node01 Falco is set to `rule_matching: all`
# for this exam (falco.yaml is part of the node checkpoint: the restore puts it back and restarts Falco),
# and the question asks for an output that identifies the new rule.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

NS="shadow-watch"
ensure_namespace "$NS"
kubectl delete pod report-agent -n "$NS" --ignore-not-found --now >/dev/null 2>&1

ssh -o StrictHostKeyChecking=no node01 'bash -s' <<'EOF'
set -e
if grep -q '^rule_matching: first' /etc/falco/falco.yaml; then
  sed -i 's/^rule_matching: first/rule_matching: all/' /etc/falco/falco.yaml
  systemctl restart falco-modern-bpf
fi
for i in $(seq 1 30); do systemctl is-active --quiet falco-modern-bpf && break; sleep 2; done
EOF

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: report-agent
  namespace: ${NS}
spec:
  nodeName: ${NODE01}
  containers:
  - {name: agent, image: "busybox:1.36.1", command: ["sleep", "86400"]}
EOF

echo "Setup completed for MHagou-001 Question 7 (namespace '$NS', Falco of $NODE01 evaluates all matching rules)"
exit 0
