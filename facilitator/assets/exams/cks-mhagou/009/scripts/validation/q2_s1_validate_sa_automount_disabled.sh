#!/bin/bash
# Item: the ServiceAccount stats-monitor-sa does not automount API credentials

V=$(kubectl get sa stats-monitor-sa -n monitoring -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null)
if [ "$V" != "false" ]; then
  echo "❌ ServiceAccount stats-monitor-sa has automountServiceAccountToken='${V:-<unset>}', expected false"
  exit 1
fi

echo "✅ stats-monitor-sa disables the automatic mounting of API credentials"
exit 0
