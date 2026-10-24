#!/bin/bash
# Item: the Dockerfile builds FROM gcr.io/distroless/base (one stage)

F="${Q5_DIR:-/tmp/exam/mhagou-008-q5}/api-server.Dockerfile"
[ -f "$F" ] || { echo "❌ $F does not exist"; exit 1; }

R=$(python3 "$(dirname "$0")/../lib/dockerfile_q5.py" "$F" base) || { echo "❌ $R"; exit 1; }

echo "✅ The base image is gcr.io/distroless/base"
exit 0
