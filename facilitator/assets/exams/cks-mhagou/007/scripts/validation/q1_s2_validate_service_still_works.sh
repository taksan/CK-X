#!/bin/bash
# Item: the Service still serves the application inside the cluster (credited only once it is internal)

NS="exposure-lab"
TYPE=$(kubectl get service nginx-external -n "$NS" -o jsonpath='{.spec.type}' 2>/dev/null)
[ "$TYPE" = "ClusterIP" ] || { echo "❌ The Service is not internal yet (type '${TYPE:-missing}')"; exit 1; }

[ "$(kubectl get service nginx-external -n "$NS" -o jsonpath='{.spec.selector.app}')" = "nginx" ] || { echo "❌ The selector of the Service was changed"; exit 1; }
[ -n "$(kubectl get endpoints nginx-external -n "$NS" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)" ] || { echo "❌ The Service has no endpoints"; exit 1; }

POD="ckx-probe-$RANDOM"
kubectl run "$POD" -n "$NS" --image=busybox:1.36.1 --restart=Never --command -- wget -q -T 8 -O /dev/null http://nginx-external.exposure-lab.svc:80/ >/dev/null 2>&1
RESULT="failed"
for i in $(seq 1 30); do
  PHASE=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
  [ "$PHASE" = "Succeeded" ] && { RESULT="ok"; break; }
  [ "$PHASE" = "Failed" ] && break
  sleep 2
done
kubectl delete pod "$POD" -n "$NS" --now --wait=false >/dev/null 2>&1

[ "$RESULT" = "ok" ] || { echo "❌ An in-cluster client cannot fetch http://nginx-external.exposure-lab.svc:80/"; exit 1; }

echo "✅ The Service still answers HTTP on port 80 inside the cluster"
exit 0
