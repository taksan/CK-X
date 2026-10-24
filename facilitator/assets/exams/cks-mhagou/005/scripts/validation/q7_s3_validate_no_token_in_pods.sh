#!/bin/bash
# Behaviour: the Pods of secure-app have no ServiceAccount token inside (and use minimal-sa)

NS="service-account-caution"
PODS=$(kubectl get pods -n "$NS" -l app=secure-app -o json 2>/dev/null | jq -r '.items[] | select(.metadata.deletionTimestamp == null and .status.phase == "Running") | .metadata.name')
[ -n "$PODS" ] || { echo "❌ No running Pod of the Deployment secure-app (label app=secure-app) in $NS"; exit 1; }

for pod in $PODS; do
  SA=$(kubectl get pod "$pod" -n "$NS" -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
  [ "$SA" = "minimal-sa" ] || { echo "❌ Pod $pod uses the ServiceAccount '$SA', expected minimal-sa"; exit 1; }
  if kubectl exec -n "$NS" "$pod" -- sh -c 'test -e /var/run/secrets/kubernetes.io/serviceaccount/token' 2>/dev/null; then
    echo "❌ Pod $pod has a ServiceAccount token mounted at /var/run/secrets/kubernetes.io/serviceaccount"
    exit 1
  fi
done

echo "✅ No ServiceAccount token is mounted in the Pods of secure-app"
exit 0
