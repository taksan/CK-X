#!/bin/bash

# Setup for CKS-003 Question 6: static analysis with kubesec. Only the manifest is provided.

WORKDIR="/tmp/exam/cks-003-q6"
mkdir -p "$WORKDIR"

cat > "$WORKDIR/kubesec-test.yaml" <<'MANIFEST'
apiVersion: v1
kind: Pod
metadata:
  name: kubesec-demo
spec:
  containers:
  - name: kubesec-demo
    image: gcr.io/google-samples/node-hello:1.0
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: true
      capabilities:
        add:
        - SYS_ADMIN
MANIFEST

echo "Setup completed for CKS-003 Question 6 (manifest in $WORKDIR)"
exit 0
