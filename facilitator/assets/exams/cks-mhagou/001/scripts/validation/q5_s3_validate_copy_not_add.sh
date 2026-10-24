#!/bin/bash
# Item: COPY is used instead of ADD (the archive is still copied and the command is kept)

F="${Q5_DOCKERFILE:-/tmp/exam/mhagou-001-q5/Dockerfile}"
[ -f "$F" ] || { echo "❌ $F does not exist"; exit 1; }

if grep -qiE '^[[:space:]]*ADD[[:space:]]' "$F"; then
  echo "❌ The Dockerfile still uses ADD"
  exit 1
fi
if ! grep -iE '^[[:space:]]*COPY[[:space:]]' "$F" | grep -q -- 'app.tar.gz'; then
  echo "❌ No COPY instruction for app.tar.gz"
  exit 1
fi
if ! grep -qE '^[[:space:]]*CMD[[:space:]].*/opt/app/run.sh' "$F"; then
  echo "❌ The CMD of the image (/opt/app/run.sh) was removed"
  exit 1
fi

echo "✅ app.tar.gz is copied with COPY and the CMD is kept"
exit 0
