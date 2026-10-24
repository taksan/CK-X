#!/bin/bash
# Every image stage uses a pinned Ubuntu version (ubuntu:<version> or a digest), not latest
F="${Q4_DOCKERFILE:-/tmp/exam/mhagou-006-q4/Dockerfile}"
[ -f "$F" ] || { echo "❌ $F does not exist"; exit 1; }
P=$(python3 "$(dirname "$0")/../lib/dockerfile_q4.py" "$F" 2>/dev/null)
[ -n "$P" ] || { echo "❌ $F cannot be parsed as a Dockerfile"; exit 1; }

echo "$P" | jq -e '(.stages | length) > 0' >/dev/null || { echo "❌ The Dockerfile has no FROM instruction"; exit 1; }
BAD=$(echo "$P" | jq -r '[.stages[].image | select((test("^(docker.io/)?(library/)?ubuntu(:[^:@]+)?(@sha256:[0-9a-f]+)?$") | not) or test(":latest$") or (test(":|@") | not))] | join(", ")')
[ -z "$BAD" ] || { echo "❌ These base images are not a pinned Ubuntu version: $BAD (use ubuntu:<version>, not latest or untagged)"; exit 1; }

echo "✅ Every stage uses a pinned Ubuntu base image"
exit 0
