#!/bin/bash

# Runs on the jumphost after the assets are extracted and BEFORE the question setups: an earlier run of this exam
# may have left Secrets encrypted in etcd that the cluster can no longer read.

"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/delete-encrypted-secrets.sh"
exit 0
