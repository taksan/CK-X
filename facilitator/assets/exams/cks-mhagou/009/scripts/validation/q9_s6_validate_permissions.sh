#!/bin/bash
# Item: by behaviour, john can list pods and secrets in namespace john

NS="john"
for res in pods secrets; do
  R=$(kubectl auth can-i list "$res" -n "$NS" --as=john --as-group=system:authenticated 2>/dev/null)
  [ "$R" = "yes" ] || { echo "❌ kubectl auth can-i says john cannot list $res in namespace $NS"; exit 1; }
done

echo "✅ john can list pods and secrets in namespace $NS"
exit 0
