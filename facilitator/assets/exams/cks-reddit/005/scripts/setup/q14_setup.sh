#!/bin/bash

# Setup for CKS-005 Question 14: Falco rule order (rule_matching: first).
# Namespace falco-lab is exclusive. The Pods invoice and mailer run on node01 and keep spawning
# processes that exist in the image (whoami, hostname): nothing is created at run time.
# A standalone Falco configuration and rules file are prepared on node01 under /tmp/exam/cks-005-q14
# (independent of the Falco service): the broad rule comes first and, with rule_matching: first,
# consumes the events that the rule written for invoice should report.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/nodes.sh"

NS="falco-lab"
DIR="/tmp/exam/cks-005-q14"

ensure_namespace "$NS"
kubectl delete pod invoice mailer -n "$NS" --ignore-not-found --now >/dev/null 2>&1

ssh -o StrictHostKeyChecking=no node01 "DIR=$DIR bash -s" <<'EOF'
mkdir -p "$DIR"
rm -f "${DIR:?}"/*
date -u +%Y-%m-%dT%H:%M:%S > "$DIR/.started"

cat > "$DIR/falco.yaml" <<'YAML'
# Standalone Falco configuration for the investigation (run: falco -c /tmp/exam/cks-005-q14/falco.yaml)
config_files:
  - /etc/falco/config.d

rules_files:
  - /tmp/exam/cks-005-q14/rules.yaml

rule_matching: first

json_output: false
stdout_output:
  enabled: true

plugins:
  - name: container
    library_path: libcontainer.so
    init_config:
      label_max_len: 100
      with_size: false
YAML

cat > "$DIR/rules.yaml" <<'YAML'
- rule: Any process in falco-lab
  desc: Every process spawned in the namespace falco-lab (SOC overview)
  condition: evt.type in (execve, execveat) and evt.dir = < and k8s.ns.name = falco-lab
  output: "BROAD | pod=%k8s.pod.name process=%proc.name"
  priority: NOTICE

- rule: Invoice process
  desc: Processes spawned in the Pod invoice
  condition: evt.type in (execve, execveat) and evt.dir = < and k8s.ns.name = falco-lab and k8s.pod.name = invoice
  output: "%evt.time.iso8601,%user.name,%proc.name"
  priority: WARNING
YAML
EOF

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata: {name: invoice, namespace: ${NS}}
spec:
  nodeName: $NODE01
  containers:
  - name: app
    image: busybox:1.36.1
    command: ["sh", "-c", "while true; do sleep 4; /bin/whoami > /dev/null; done"]
---
apiVersion: v1
kind: Pod
metadata: {name: mailer, namespace: ${NS}}
spec:
  nodeName: $NODE01
  containers:
  - name: app
    image: busybox:1.36.1
    command: ["sh", "-c", "while true; do sleep 3; /bin/hostname > /dev/null; done"]
EOF

echo "Setup completed for CKS-005 Question 14 (namespace '$NS', Falco files in $DIR on $NODE01)"
exit 0
