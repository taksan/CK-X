#!/bin/bash
# Item: the container runs as test-user (UID 5487) instead of root

F="${Q11_DOCKERFILE:-/tmp/exam/mhagou-009-q11/Dockerfile}"
[ -f "$F" ] || { echo "❌ $F does not exist"; exit 1; }
WHY=$(python3 "$(dirname "$0")/../lib/dockerfile_q11.py" user "$F") || { echo "❌ $WHY"; exit 1; }
echo "✅ The Dockerfile selects test-user (UID 5487)"
exit 0
