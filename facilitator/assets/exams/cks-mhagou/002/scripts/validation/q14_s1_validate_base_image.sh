#!/bin/bash
# The base image of the Dockerfile is pinned to a specific ubuntu version (tag or digest), not latest
exec python3 "$(dirname "$0")/../lib/dockerfile_q14.py" "${Q14_FILE:-/tmp/exam/mhagou-002-q14/Dockerfile}" base
