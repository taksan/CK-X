#!/bin/bash
# The Dockerfile ends with an unprivileged user (the last USER instruction is not root)
exec python3 "$(dirname "$0")/../lib/dockerfile_q14.py" "${Q14_FILE:-/tmp/exam/mhagou-002-q14/Dockerfile}" user
