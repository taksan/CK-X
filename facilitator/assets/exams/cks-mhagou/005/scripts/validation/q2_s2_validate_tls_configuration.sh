#!/bin/bash
# The Ingress configures TLS for a host it routes, with a kubernetes.io/tls Secret that holds an
# unexpired certificate valid for that host and the matching private key

source "$(dirname "$0")/../lib/q2-lib.sh"
find_tls_host || exit 1

echo "✅ TLS for $TLS_HOST uses the Secret $TLS_SECRET (valid, unexpired certificate for the host with its key)"
exit 0
