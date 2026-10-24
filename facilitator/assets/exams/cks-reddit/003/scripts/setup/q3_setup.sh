#!/bin/bash

# Setup for CKS-003 Question 3: scan images with Trivy. Only a working directory is needed.

WORKDIR="/tmp/exam/cks-003-q3"
mkdir -p "$WORKDIR"
rm -f "${WORKDIR:?}"/*

echo "Setup completed for CKS-003 Question 3 (output directory $WORKDIR)"
exit 0
