#!/bin/bash
# Validate by behaviour: a probe Pod that opens /dev/mem on node01 makes the running Falco raise the
# WARNING alert with the requested output

source "$(dirname "$0")/../lib/nodes.sh"
source "$(dirname "$0")/../lib/falco-devmem.sh"
run_devmem_probe || exit 1

if ! grep -Eq -- 'Warning .*Sensitive file opened \(user=[^ ]+ command=.*file=/dev/mem\)' "$PROBE_JOURNAL"; then
  if grep -Eq -- 'Sensitive file opened .*file=/dev/mem' "$PROBE_JOURNAL"; then
    echo "❌ Falco reports /dev/mem but not with priority Warning"
  else
    echo "❌ Falco on ${NODE01} raised no 'Sensitive file opened (...file=/dev/mem)' alert while a Pod opened /dev/mem (rule loaded? Falco reloaded or restarted? rule order: rule_matching is 'first')"
  fi
  exit 1
fi

echo "✅ Falco on ${NODE01} raises the WARNING alert 'Sensitive file opened' for /dev/mem"
exit 0
