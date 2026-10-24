#!/bin/bash
# Item: no package installation, shell setup or other unnecessary instruction remains and only
# app-server is copied to /app/server

F="${Q5_DIR:-/tmp/exam/mhagou-008-q5}/api-server.Dockerfile"
[ -f "$F" ] || { echo "❌ $F does not exist"; exit 1; }

R=$(python3 "$(dirname "$0")/../lib/dockerfile_q5.py" "$F" instructions) || { echo "❌ $R"; exit 1; }

echo "✅ Only FROM, COPY (app-server -> /app/server), USER and ENTRYPOINT remain"
exit 0
