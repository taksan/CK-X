#!/bin/bash
# Validate the Dockerfile: base image pinned (tag or digest) and the final USER is unprivileged;
# nothing else added or removed

F="${Q10_DOCKERFILE:-/tmp/exam/cks-004-q10/Dockerfile}"
[ -f "$F" ] || { echo "❌ $F does not exist"; exit 1; }

FROM=$(grep -E '^FROM ' "$F" | head -1 | awk '{print $2}')
case "$FROM" in
  ubuntu@sha256:*|ubuntu:*@sha256:*) ;;
  ubuntu:latest|ubuntu|"") echo "❌ The base image '$FROM' is not pinned to a version"; exit 1;;
  ubuntu:*) ;;
  *) echo "❌ The base image must remain ubuntu (a pinned version), found '$FROM'"; exit 1;;
esac

LAST_USER=$(grep -E '^USER ' "$F" | tail -1 | awk '{print $2}')
# any unprivileged user is valid: nobody / 65535, or the user the Dockerfile itself creates (reportuser)
case "$LAST_USER" in
  ""|root|root:*|0|0:*) echo "❌ The last USER is '${LAST_USER:-none}': the container must not run as root"; exit 1;;
  nobody|nobody:*|65535|65535:*) ;;
  *) grep -qE "useradd .*\b${LAST_USER%%:*}\b" "$F" || { echo "❌ The last USER '$LAST_USER' is not created in the Dockerfile and is not nobody / 65535"; exit 1; };;
esac

# nothing added or removed
n() { grep -cE "$1" "$F"; }
if [ "$(n '^FROM ')" != 1 ] || [ "$(n '^USER ')" != 2 ] || [ "$(n '^RUN ')" != 3 ] || [ "$(n '^ARG ')" != 3 ] \
   || [ "$(n '^COPY ')" != 2 ] || [ "$(n '^(ENV|SHELL|ENTRYPOINT|CMD|EXPOSE|VOLUME) ')" != 6 ]; then
  echo "❌ Instructions were added or removed: only existing settings may be modified"
  exit 1
fi
if [ "$(grep -E '^USER ' "$F" | head -1 | awk '{print $2}')" != "root" ]; then
  echo "❌ The first USER root (needed to install packages) must stay as it is"
  exit 1
fi

echo "✅ Dockerfile: pinned base image and unprivileged final user"
exit 0
