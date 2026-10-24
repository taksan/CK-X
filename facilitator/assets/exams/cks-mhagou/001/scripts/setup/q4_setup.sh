#!/bin/bash

# Setup for MHagou-001 Question 4: a Cilium deny policy. Namespace team-azure is exclusive.
# messenger (role=messenger) must not reach db (role=database); everything else keeps working:
# cache (role=cache) is reachable by messenger, reporter (role=reporting) reaches db.
# busybox httpd on port 80 stands in for the servers.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="team-azure"
ensure_namespace "$NS"
kubectl delete ciliumnetworkpolicy p1 -n "$NS" --ignore-not-found >/dev/null 2>&1

# With Cilium an endpoint selected by ANY egress rule (even a deny rule) is in default deny for the egress
# unless an allow rule exists: the namespace has a baseline allow policy, as clusters with Cilium usually do,
# so that "deny only this traffic" works as the question says.
kubectl apply -f - >/dev/null <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: baseline-allow
  namespace: ${NS}
spec:
  endpointSelector: {}
  ingress:
  - fromEntities: ["all"]
  egress:
  - toEntities: ["all"]
---
apiVersion: v1
kind: Pod
metadata:
  name: messenger
  namespace: ${NS}
  labels: {role: messenger}
spec:
  containers:
  - {name: c, image: "busybox:1.36.1", command: ["sleep", "86400"]}
---
apiVersion: v1
kind: Pod
metadata:
  name: db
  namespace: ${NS}
  labels: {role: database}
spec:
  containers:
  - name: c
    image: busybox:1.36.1
    command: ["sh", "-c", "mkdir -p /www && echo db > /www/index.html && exec httpd -f -p 80 -h /www"]
---
apiVersion: v1
kind: Pod
metadata:
  name: cache
  namespace: ${NS}
  labels: {role: cache}
spec:
  containers:
  - name: c
    image: busybox:1.36.1
    command: ["sh", "-c", "mkdir -p /www && echo cache > /www/index.html && exec httpd -f -p 80 -h /www"]
---
apiVersion: v1
kind: Pod
metadata:
  name: reporter
  namespace: ${NS}
  labels: {role: reporting}
spec:
  containers:
  - {name: c, image: "busybox:1.36.1", command: ["sleep", "86400"]}
EOF

echo "Setup completed for MHagou-001 Question 4 (namespace '$NS')"
exit 0
