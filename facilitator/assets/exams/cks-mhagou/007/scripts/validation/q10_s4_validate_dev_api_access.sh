#!/bin/bash
# Item: the env=dev Pods reach the Kubernetes API server over HTTPS although the initial deny stays in place

source "$(dirname "$0")/../lib/cilium-probe.sh"
cilium_fixtures_ready || exit 1
kubectl -n dev-clients get networkpolicy dev-initial-deny >/dev/null 2>&1 || { echo "❌ The provided NetworkPolicy dev-initial-deny was deleted: it must stay, the access has to be allowed by a new policy"; exit 1; }

API=$(kubectl -n default get service kubernetes -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
for pod in cks-dev cks-dev-other; do
  allowed "" dev-clients $pod "$API" 443 api || { echo "❌ dev-clients/$pod (env=dev) cannot reach the Kubernetes API server over HTTPS"; exit 1; }
done

echo "✅ The env=dev Pods reach the Kubernetes API server (HTTPS)"
exit 0
