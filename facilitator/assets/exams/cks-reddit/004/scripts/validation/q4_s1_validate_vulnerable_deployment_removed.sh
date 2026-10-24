#!/bin/bash
# Validate the Deployment running a vulnerable image is gone (its Pods too) and the clean
# workloads were kept

NS="scan-lab"

if kubectl get deployment storefront -n "$NS" >/dev/null 2>&1; then
  echo "❌ The Deployment 'storefront' runs nginx:1.16 (HIGH/CRITICAL vulnerabilities) and still exists"
  exit 1
fi
if [ -n "$(kubectl get pods -n "$NS" -l app=storefront --no-headers 2>/dev/null | grep -v Terminating)" ]; then
  echo "❌ Pods of the vulnerable Deployment are still running"
  exit 1
fi

kubectl get deployment gateway -n "$NS" >/dev/null 2>&1 || { echo "❌ Deployment 'gateway' (alpine:3.20, no HIGH/CRITICAL findings) was deleted"; exit 1; }
kubectl get pod worker -n "$NS" >/dev/null 2>&1 || { echo "❌ Pod 'worker' (busybox:1.36.1, no HIGH/CRITICAL findings) was deleted"; exit 1; }

echo "✅ The vulnerable Deployment is gone and the clean workloads were kept"
exit 0
