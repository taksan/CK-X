#!/bin/bash
# Validate the Dockerfile: base image pinned (not floating "latest") and not running as root

WORKDIR="${Q3_WORKDIR:-/tmp/exam/cks-002-q3}"
DOCKERFILE_PATH="$WORKDIR/Dockerfile"

if [ ! -f "$DOCKERFILE_PATH" ]; then
  echo "❌ Dockerfile not found at $DOCKERFILE_PATH"
  exit 1
fi

# --- base image: a fixed tag or a digest, never an untagged/latest image
FROM_IMAGE=$(grep -Ei '^[[:space:]]*FROM[[:space:]]' "$DOCKERFILE_PATH" | head -1 | awk '{print $2}')
if [ -z "$FROM_IMAGE" ]; then
  echo "❌ No FROM instruction found"
  exit 1
fi

if [[ "$FROM_IMAGE" == *@sha256:* ]]; then
  : # pinned by digest
else
  TAG="${FROM_IMAGE##*:}"
  if [ "$TAG" = "$FROM_IMAGE" ] || [ "$TAG" = "latest" ]; then
    echo "❌ Base image '$FROM_IMAGE' is not pinned: use a fixed version tag or a digest instead of latest"
    exit 1
  fi
fi

# --- user: the last USER instruction must be test-user / 5375, not root
LAST_USER=$(grep -Ei '^[[:space:]]*USER[[:space:]]' "$DOCKERFILE_PATH" | tail -1 | awk '{print $2}')
if [ -z "$LAST_USER" ]; then
  echo "❌ Dockerfile has no USER instruction"
  exit 1
fi

USER_PART="${LAST_USER%%:*}"
case "${USER_PART,,}" in
  test-user|5375) ;;
  root|0) echo "❌ Dockerfile still runs as root (USER $LAST_USER)"; exit 1 ;;
  *) echo "❌ USER must be test-user (UID 5375), found '$LAST_USER'"; exit 1 ;;
esac

echo "✅ Dockerfile pins the base image ($FROM_IMAGE) and runs as '$LAST_USER'"
exit 0
