#!/bin/bash
# Validate the Pod running a vulnerable image is gone and the clean workloads were kept

NS="scan-lab"

if [ -n "$(kubectl get pod reports -n "$NS" --no-headers 2>/dev/null | grep -v Terminating)" ]; then
  echo "❌ The Pod 'reports' runs httpd:2.4.49 (HIGH/CRITICAL vulnerabilities) and still exists"
  exit 1
fi

kubectl get deployment gateway -n "$NS" >/dev/null 2>&1 || { echo "❌ Deployment 'gateway' (alpine:3.20, no HIGH/CRITICAL findings) was deleted"; exit 1; }
kubectl get pod worker -n "$NS" >/dev/null 2>&1 || { echo "❌ Pod 'worker' (busybox:1.36.1, no HIGH/CRITICAL findings) was deleted"; exit 1; }

echo "✅ The vulnerable Pod is gone and the clean workloads were kept"
exit 0
