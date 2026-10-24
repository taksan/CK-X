#!/bin/bash

# Setup for MHagou-001 Question 9: NetworkPolicy for redis-backend.
# Namespaces prod-x12cs (the target), prod-yx13cs (allowed as a whole, labelled access=redis) and
# prod-zz14cs (a stranger) are exclusive to this question. The Pod redis-backend listens on TCP 6379
# (and on 8080, to check that only the requested port is open); busybox httpd stands in for redis.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace prod-x12cs
ensure_namespace prod-yx13cs
ensure_namespace prod-zz14cs
kubectl label namespace prod-yx13cs access=redis --overwrite >/dev/null
kubectl delete networkpolicy allow-redis-access -n prod-x12cs --ignore-not-found >/dev/null 2>&1

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: redis-backend
  namespace: prod-x12cs
  labels: {run: redis-backend}
spec:
  containers:
  - name: redis
    image: busybox:1.36.1
    command:
    - sh
    - -c
    - |
      mkdir -p /www && echo PONG > /www/index.html
      httpd -p 8080 -h /www
      exec httpd -f -p 6379 -h /www
    ports: [{containerPort: 6379}]
---
apiVersion: v1
kind: Service
metadata:
  name: redis-backend
  namespace: prod-x12cs
spec:
  type: ClusterIP
  selector: {run: redis-backend}
  ports: [{port: 6379, targetPort: 6379}]
---
apiVersion: v1
kind: Pod
metadata:
  name: app-worker
  namespace: prod-x12cs
  labels: {backend: prod-x12cs}
spec:
  containers:
  - {name: c, image: "busybox:1.36.1", command: ["sleep", "86400"]}
---
apiVersion: v1
kind: Pod
metadata:
  name: batch-worker
  namespace: prod-x12cs
  labels: {role: batch}
spec:
  containers:
  - {name: c, image: "busybox:1.36.1", command: ["sleep", "86400"]}
---
apiVersion: v1
kind: Pod
metadata:
  name: partner-client
  namespace: prod-yx13cs
  labels: {role: partner}
spec:
  containers:
  - {name: c, image: "busybox:1.36.1", command: ["sleep", "86400"]}
---
apiVersion: v1
kind: Pod
metadata:
  name: stranger
  namespace: prod-zz14cs
  labels: {role: stranger}
spec:
  containers:
  - {name: c, image: "busybox:1.36.1", command: ["sleep", "86400"]}
EOF

echo "Setup completed for MHagou-001 Question 9 (namespaces prod-x12cs, prod-yx13cs, prod-zz14cs)"
exit 0
