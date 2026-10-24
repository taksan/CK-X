#!/bin/bash
# Validate the rule is specific: the probe also opens /dev/mem2, which must NOT raise the alert
# (credited only when the alert for /dev/mem itself fires)

source "$(dirname "$0")/../lib/falco-devmem.sh"
run_devmem_probe || exit 1

grep -Eq -- 'Sensitive file opened \(user=[^ ]+ command=.*file=/dev/mem\)' "$PROBE_JOURNAL" \
  || { echo "❌ No alert for /dev/mem yet: nothing to credit"; exit 1; }

if grep -Eq -- 'Sensitive file opened .*file=/dev/mem2' "$PROBE_JOURNAL"; then
  echo "❌ The rule also fires for /dev/mem2: the condition must match the file /dev/mem exactly"
  exit 1
fi

echo "✅ The rule fires for /dev/mem only"
exit 0
