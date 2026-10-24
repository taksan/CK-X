#!/bin/bash

# Setup for MHagou-003 Question 8: an SPDX SBOM of nginx:1.19 (files only, jumphost).
# The output directory is prepared; trivy is installed on the jumphost.

source "$(dirname "$0")/../lib/wait-cluster.sh"

DIR="/tmp/exam/mhagou-003-q8"
mkdir -p "${DIR:?}"
rm -f "${DIR:?}"/*

echo "Setup completed for MHagou-003 Question 8 (directory $DIR)"
exit 0
