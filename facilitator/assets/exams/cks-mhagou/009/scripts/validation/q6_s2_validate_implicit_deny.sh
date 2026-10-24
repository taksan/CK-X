#!/bin/bash
# Item: the active configuration denies when the backend cannot decide (defaultAllow: false)

source "$(dirname "$0")/../lib/imagepolicy.sh"
ipw_load || exit 1

if [ "$(echo "$IPW_CFG" | jq -r '.defaultAllow')" != "false" ]; then
  echo "❌ defaultAllow is '$(echo "$IPW_CFG" | jq -r '.defaultAllow')' in the active configuration: it must be false (implicit deny)"
  exit 1
fi

echo "✅ The active configuration is an implicit deny (defaultAllow: false)"
exit 0
