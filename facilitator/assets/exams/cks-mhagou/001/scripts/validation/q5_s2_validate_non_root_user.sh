#!/bin/bash
# Item: the image runs as a non-root user (the last USER instruction is not root / 0)

F="${Q5_DOCKERFILE:-/tmp/exam/mhagou-001-q5/Dockerfile}"
[ -f "$F" ] || { echo "❌ $F does not exist"; exit 1; }

LAST=$(grep -iE '^[[:space:]]*USER[[:space:]]' "$F" | tail -1 | awk '{print $2}')
if [ -z "$LAST" ]; then
  echo "❌ The Dockerfile has no USER instruction: the container runs as root"
  exit 1
fi
USERPART=${LAST%%:*}
case "$USERPART" in
  root|0) echo "❌ The last USER instruction is '$LAST': the container still runs as root"; exit 1 ;;
esac

echo "✅ The container runs as '$LAST'"
exit 0
