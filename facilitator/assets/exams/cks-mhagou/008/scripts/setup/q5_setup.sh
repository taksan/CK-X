#!/bin/bash

# Setup for MHAGOU-008 Question 5: harden a Dockerfile (a file on the jumphost, nothing is
# deployed, so no namespace is needed). The binary app-server is a harmless native executable.

DIR="/tmp/exam/mhagou-008-q5"
mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/api-server.Dockerfile "${DIR:?}"/app-server

install -m 0755 /bin/true "$DIR/app-server"

cat > "$DIR/api-server.Dockerfile" <<'EOF'
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y curl wget python3 python3-pip
RUN useradd -m appuser
COPY ./app-server /app/server
RUN chmod +x /app/server
USER root
ENTRYPOINT /app/server
EOF

echo "Setup completed for MHAGOU-008 Question 5 (Dockerfile $DIR/api-server.Dockerfile)"
exit 0
