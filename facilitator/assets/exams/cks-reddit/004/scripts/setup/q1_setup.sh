#!/bin/bash

# Setup for CKS-004 Question 1: CiliumNetworkPolicies in team-dev (exclusive to this question)
#
# default-allow (given) allows the traffic inside the namespace and DNS. Pods:
#   database-0  role=database       api-service x2  role=api-service
#   stuff x2    role=stuff          backend-0       role=backend, behind the Service "backend"

source "$(dirname "$0")/../lib/wait-cluster.sh"

NAMESPACE="team-dev"

ensure_namespace "$NAMESPACE"
kubectl delete ciliumnetworkpolicy team-dev team-dev-2 -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1

kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: default-allow
  namespace: ${NAMESPACE}
spec:
  endpointSelector: {}
  ingress:
  - fromEndpoints:
    - {}
  egress:
  - toEndpoints:
    - {}
  - toEndpoints:
    - matchLabels:
        k8s:io.kubernetes.pod.namespace: kube-system
        k8s:k8s-app: kube-dns
    toPorts:
    - ports:
      - port: "53"
        protocol: ANY
---
apiVersion: v1
kind: Pod
metadata:
  name: database-0
  namespace: ${NAMESPACE}
  labels:
    role: database
spec:
  containers:
  - name: db
    image: busybox:1.36.1
    command: ["sh", "-c", "sleep 36000"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
  namespace: ${NAMESPACE}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-service
  template:
    metadata:
      labels:
        app: api-service
        role: api-service
    spec:
      containers:
      - name: api
        image: nginx:1.27-alpine
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stuff
  namespace: ${NAMESPACE}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: stuff
  template:
    metadata:
      labels:
        app: stuff
        role: stuff
    spec:
      containers:
      - name: stuff
        image: busybox:1.36.1
        command: ["sh", "-c", "sleep 36000"]
---
apiVersion: v1
kind: Pod
metadata:
  name: backend-0
  namespace: ${NAMESPACE}
  labels:
    role: backend
spec:
  containers:
  - name: backend
    image: nginx:1.27-alpine
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: ${NAMESPACE}
spec:
  selector:
    role: backend
  ports:
  - port: 80
    targetPort: 80
EOF

echo "Setup completed for CKS-004 Question 1 (namespace '$NAMESPACE')"
exit 0
