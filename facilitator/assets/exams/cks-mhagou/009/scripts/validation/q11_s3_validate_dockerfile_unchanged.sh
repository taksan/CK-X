#!/bin/bash
# Item: no other instruction of the Dockerfile was added, removed or modified (credited once base and user are fixed)

F="${Q11_DOCKERFILE:-/tmp/exam/mhagou-009-q11/Dockerfile}"
[ -f "$F" ] || { echo "❌ $F does not exist"; exit 1; }
WHY=$(python3 "$(dirname "$0")/../lib/dockerfile_q11.py" rest "$F") || { echo "❌ $WHY"; exit 1; }
echo "✅ The other instructions are untouched"
exit 0
