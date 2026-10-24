#!/bin/bash
# Item: the container runs as the distroless non-root user (nonroot / 65532)

F="${Q5_DIR:-/tmp/exam/mhagou-008-q5}/api-server.Dockerfile"
[ -f "$F" ] || { echo "❌ $F does not exist"; exit 1; }

R=$(python3 "$(dirname "$0")/../lib/dockerfile_q5.py" "$F" user) || { echo "❌ $R"; exit 1; }

echo "✅ The container runs as nonroot (65532)"
exit 0
