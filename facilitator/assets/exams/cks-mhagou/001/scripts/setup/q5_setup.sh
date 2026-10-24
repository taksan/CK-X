#!/bin/bash

# Setup for MHagou-001 Question 5: harden a Dockerfile and a Deployment manifest (files only).
# No namespace: nothing is deployed, the files are for the candidate to edit.

source "$(dirname "$0")/../lib/wait-cluster.sh"

DIR="/tmp/exam/mhagou-001-q5"
mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*

cat > "$DIR/Dockerfile" <<'EOF'
FROM ubuntu:latest
USER root
RUN apt-get update && apt-get install -y curl
ADD app.tar.gz /opt/app/
CMD ["/opt/app/run.sh"]
EOF

cat > "$DIR/deployment.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: report-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: report-app
  template:
    metadata:
      labels:
        app: report-app
    spec:
      containers:
      - name: app
        image: myregistry/report-app:latest
        securityContext:
          privileged: true
EOF

echo "Setup completed for MHagou-001 Question 5 (files in $DIR)"
exit 0
