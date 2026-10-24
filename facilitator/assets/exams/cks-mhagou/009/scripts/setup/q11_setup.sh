#!/bin/bash

# Setup for MHagou CKS exam 9, Question 11: harden a Dockerfile and a Pod manifest (files only).
# The files are on the jumphost in /tmp/exam/mhagou-009-q11/. Nothing is built or applied.

DIR="/tmp/exam/mhagou-009-q11"
mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*

cat > "$DIR/Dockerfile" <<'EOF'
FROM ubuntu:latest
RUN apt-get update -y
RUN apt-install nginx -y
COPY entrypoint.sh /
ENTRYPOINT ['/entrypoint.sh']
USER root
EOF

cat > "$DIR/deployment.yaml" <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo-2
spec:
  securityContext:
    runAsUser: 1000
  containers:
    - name: sec-ctx-demo-2
      image: gcr.io/google-samples/node-hello:1.0
      securityContext:
        runAsUser: 0
        privileged: true
        allowPrivilegeEscalation: false
EOF

echo "Setup completed for MHagou exam 9 Question 11 (files in $DIR)"
exit 0
