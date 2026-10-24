#!/bin/bash
# Item: /app/server is the ENTRYPOINT, in exec form

F="${Q5_DIR:-/tmp/exam/mhagou-008-q5}/api-server.Dockerfile"
[ -f "$F" ] || { echo "❌ $F does not exist"; exit 1; }

R=$(python3 "$(dirname "$0")/../lib/dockerfile_q5.py" "$F" entrypoint) || { echo "❌ $R"; exit 1; }

echo "✅ ENTRYPOINT [\"/app/server\"] in exec form"
exit 0
