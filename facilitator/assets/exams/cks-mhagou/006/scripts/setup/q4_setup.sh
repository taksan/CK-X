#!/bin/bash

# Setup for MHagou-006 Question 4: a Dockerfile and a Deployment manifest to harden. Files only
# (jumphost), nothing is built or deployed: /tmp/exam/mhagou-006-q4/{Dockerfile,Deployment.yaml}.
# The manifest uses a removed API version and has an init container with the same flaws.

source "$(dirname "$0")/../lib/wait-cluster.sh"

DIR="/tmp/exam/mhagou-006-q4"
mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*

cat > "$DIR/Dockerfile" <<'DOCKERFILE'
FROM ubuntu:latest
USER root
RUN apt-get install -y lsof=4.72 wget=1.17.1 nginx=4.2
ENV ENVIRONMENT=testing
USER root
CMD ["nginx", "-g", "daemon off;"]
DOCKERFILE

cat > "$DIR/Deployment.yaml" <<'YAML'
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  labels:
    app: kafka
  name: kafka
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kafka
  template:
    metadata:
      labels:
        app: kafka
    spec:
      initContainers:
        - name: prepare
          image: busybox:1.36.1
          command: ["sh", "-c", "echo preparing"]
          securityContext:
            privileged: true
            readOnlyRootFilesystem: false
      containers:
        - image: bitnami/kafka
          name: kafka
          volumeMounts:
            - name: kafka-vol
              mountPath: /var/lib/kafka
          securityContext:
            capabilities:
              add: [NET_ADMIN]
              drop: [ALL]
            privileged: true
            readOnlyRootFilesystem: false
            runAsUser: 65535
          resources: {}
      volumes:
        - name: kafka-vol
          emptyDir: {}
YAML

echo "Setup completed for MHagou-006 Question 4 (files in $DIR)"
exit 0
