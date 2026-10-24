#!/bin/bash
# Validate that the only Service meant to be public (portal) is still exposed, and that the
# internal Services were fixed (so that deleting everything is not a solution)

NS="exposed-lab"
[ "$(kubectl get svc portal -n "$NS" -o jsonpath='{.spec.type}' 2>/dev/null)" = "NodePort" ] || { echo "❌ Service 'portal' must stay a NodePort Service (it is the public one)"; exit 1; }
[ "$(kubectl get svc reports -n "$NS" -o jsonpath='{.spec.type}' 2>/dev/null)" = "ClusterIP" ] || { echo "❌ The internal Services are not fixed yet"; exit 1; }
[ "$(kubectl get svc admin -n "$NS" -o jsonpath='{.spec.type}' 2>/dev/null)" = "ClusterIP" ] || { echo "❌ The internal Services are not fixed yet"; exit 1; }
kubectl get svc cache -n "$NS" >/dev/null 2>&1 || { echo "❌ Service 'cache' was deleted"; exit 1; }

echo "✅ portal is still public; the others are internal"
exit 0
