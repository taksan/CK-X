#!/bin/bash
# Item: the Ubuntu base image is pinned to an explicit release tag or digest

F="${Q11_DOCKERFILE:-/tmp/exam/mhagou-009-q11/Dockerfile}"
[ -f "$F" ] || { echo "❌ $F does not exist"; exit 1; }
WHY=$(python3 "$(dirname "$0")/../lib/dockerfile_q11.py" base "$F") || { echo "❌ $WHY"; exit 1; }
echo "✅ The base image is pinned"
exit 0
