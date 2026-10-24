#!/bin/bash
# The other instructions are untouched (WORKDIR, both COPY, npm ci, CMD). Credited only when at least
# one fix was made (an unmodified file would otherwise be a free mark).

F="${Q14_FILE:-/tmp/exam/mhagou-002-q14/Dockerfile}"
H="$(dirname "$0")/../lib/dockerfile_q14.py"
python3 "$H" "$F" kept || exit 1
if python3 "$H" "$F" base >/dev/null && ! python3 "$H" "$F" user >/dev/null; then :; fi
if ! python3 "$H" "$F" base >/dev/null && ! python3 "$H" "$F" user >/dev/null && ! python3 "$H" "$F" apt >/dev/null; then
  echo "❌ The Dockerfile has not been hardened yet"
  exit 1
fi
echo "✅ The other instructions were kept"
exit 0
