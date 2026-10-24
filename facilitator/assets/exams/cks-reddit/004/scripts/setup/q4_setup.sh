#!/bin/bash

# Setup for CKS-004 Question 4: scan the images of the workloads of scan-lab (exclusive to this
# question) with Trivy and delete the ones that run severely vulnerable images.
#   storefront (Deployment)  nginx:1.16       166 HIGH/CRITICAL findings
#   reports (Pod)            httpd:2.4.49     122
#   worker (Pod)             busybox:1.36.1   none
#   gateway (Deployment)     alpine:3.20      none

source "$(dirname "$0")/../lib/wait-cluster.sh"

NAMESPACE="scan-lab"

ensure_namespace "$NAMESPACE"

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: storefront
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: storefront
  template:
    metadata:
      labels:
        app: storefront
    spec:
      containers:
      - name: web
        image: nginx:1.16
---
apiVersion: v1
kind: Pod
metadata:
  name: reports
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: web
    image: httpd:2.4.49
---
apiVersion: v1
kind: Pod
metadata:
  name: worker
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: worker
    image: busybox:1.36.1
    command: ["sh", "-c", "sleep 36000"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gateway
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gateway
  template:
    metadata:
      labels:
        app: gateway
    spec:
      containers:
      - name: gateway
        image: alpine:3.20
        command: ["sh", "-c", "sleep 36000"]
EOF

echo "Setup completed for CKS-004 Question 4 (namespace '$NAMESPACE')"
exit 0
