#!/bin/bash
# apt-get update and apt-get install share one RUN instruction and still install wget and curl
exec python3 "$(dirname "$0")/../lib/dockerfile_q14.py" "${Q14_FILE:-/tmp/exam/mhagou-002-q14/Dockerfile}" apt
