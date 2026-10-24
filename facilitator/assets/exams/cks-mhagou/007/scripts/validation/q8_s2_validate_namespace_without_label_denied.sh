#!/bin/bash
# Item: a namespace named lab-... without the label env is rejected

source "$(dirname "$0")/../lib/nspolicy.sh"
ns_denied_probe || { echo "❌ A namespace lab-... without the label env is accepted by the API server"; exit 1; }

echo "✅ A namespace lab-... without the label env is rejected"
exit 0
