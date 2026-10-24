#!/bin/bash
# Item: the base image of the Dockerfile is pinned (a version tag or a digest, not latest/untagged)

F="${Q5_DOCKERFILE:-/tmp/exam/mhagou-001-q5/Dockerfile}"
[ -f "$F" ] || { echo "❌ $F does not exist"; exit 1; }

FROM=$(grep -iE '^[[:space:]]*FROM[[:space:]]' "$F" | head -1 | sed -E 's/^[[:space:]]*[Ff][Rr][Oo][Mm][[:space:]]+(--platform=[^[:space:]]+[[:space:]]+)?//' | awk '{print $1}')
[ -n "$FROM" ] || { echo "❌ No FROM instruction in $F"; exit 1; }

case "$FROM" in
  *@sha256:*) ;;
  *:latest) echo "❌ The base image '$FROM' uses the latest tag"; exit 1 ;;
  *:*) ;;
  *) echo "❌ The base image '$FROM' has no tag (it means latest)"; exit 1 ;;
esac

echo "✅ The base image '$FROM' is pinned"
exit 0
