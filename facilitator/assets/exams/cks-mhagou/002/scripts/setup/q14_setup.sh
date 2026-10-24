#!/bin/bash

# Setup for MHAGOU-002 Question 14: a Dockerfile to harden. Files only, no namespace.

source "$(dirname "$0")/../lib/wait-cluster.sh"

DIR="/tmp/exam/mhagou-002-q14"
mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*

cat > "$DIR/Dockerfile" <<'EOF'
FROM ubuntu:latest

ENV CI=true

RUN apt-get update
RUN apt-get install -y wget
RUN apt-get install -y curl

USER root

WORKDIR /code
COPY package.json package-lock.json /code/
RUN npm ci
COPY src /code/src

CMD [ "npm", "start" ]
EOF

echo "Setup completed for MHAGOU-002 Question 14 (Dockerfile in $DIR)"
exit 0
