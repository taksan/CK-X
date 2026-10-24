#!/bin/bash

# Setup for CKS-004 Question 10: fix a Dockerfile and a Deployment manifest (files on the jumphost).
# Each file has exactly two insecure settings; everything else is acceptable and must be left alone.
# Exclusive namespace: none needed (files only, nothing is deployed).

source "$(dirname "$0")/../lib/wait-cluster.sh"

DIR="/tmp/exam/cks-004-q10"
mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*

cat > "$DIR/Dockerfile" <<'EOF'
FROM ubuntu:latest
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    runit=2.1.2-59ubuntu1 wget=1.21.4-1ubuntu4 \
    lsof=4.95.0-1build3 net-tools=2.10-0.1ubuntu4 && \
    apt-get autoremove -y && apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ARG APP_VERSION=6.5.1
ARG APP_BASE_URL=https://downloads.example.org/releases/6.5.1
ARG APP_FILE=reportd_6.5.1_amd64.deb

ENV PATH=$PATH:/opt/reportd/bin

RUN groupadd -g 1001 reportgroup && useradd -u 1001 -g reportgroup -M reportuser

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN wget -q -O ${APP_FILE} ${APP_BASE_URL}/${APP_FILE} && \
    dpkg -i ${APP_FILE} && \
    rm -f ${APP_FILE}

COPY scripts/entrypoint.sh /
COPY scripts/healthcheck.sh /usr/local/bin/

ENTRYPOINT ["/entrypoint.sh"]
USER root

CMD ["reportd"]

EXPOSE 8091
VOLUME /opt/reportd/var
EOF

cat > "$DIR/deployment.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: report-db
  labels:
    app: report-db
spec:
  replicas: 1
  selector:
    matchLabels:
      app: report-db
  template:
    metadata:
      labels:
        app: report-db
    spec:
      containers:
      - name: report-db
        image: mysql:8.4
        resources:
          requests:
            cpu: "100m"
            memory: 256Mi
          limits:
            cpu: "500m"
            memory: 512Mi
        securityContext:
          runAsUser: 0
          privileged: true
          readOnlyRootFilesystem: true
          capabilities:
            add: ["NET_BIND_SERVICE"]
            drop: ["ALL"]
        env:
        - name: MYSQL_DATABASE
          value: reports
      volumes:
      - name: db-storage
        emptyDir: {}
EOF
echo "Setup completed for CKS-004 Question 10 (files in $DIR)"
exit 0
