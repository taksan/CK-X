#!/bin/bash

# Setup for Question 3: Dockerfile and Pod manifest hardening

WORKDIR="/tmp/exam/cks-002-q3"
mkdir -p "$WORKDIR"

DOCKERFILE_PATH="$WORKDIR/Dockerfile"
POD_PATH="$WORKDIR/pod.yaml"

# Write the insecure Dockerfile
cat > "$DOCKERFILE_PATH" <<'EOF'
FROM ubuntu:latest
RUN apt-get update -y
RUN apt-get install nginx -y
COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
USER ROOT
EOF

# Write the insecure Pod manifest
cat > "$POD_PATH" <<'EOF'
---
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo-2
spec:
  securityContext:
    runAsUser: 1000
  containers:
  - name: security-context-demo-2
    image: gcr.io/google-samples/node-hello:1.0
    securityContext:
      runAsUser: 0
      privileged: true
      allowPrivilegeEscalation: false
EOF

echo "Setup completed for CKS-002 Question 3. Files are in $WORKDIR"
exit 0
