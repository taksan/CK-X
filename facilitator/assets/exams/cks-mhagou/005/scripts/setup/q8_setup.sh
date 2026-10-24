#!/bin/bash

# Setup for MHagou-005 Question 8: restrict the access to the Kubernetes API from a namespace.
# Namespace api-restrict is exclusive. admin-pod (role=admin) and restricted-pod (role=restricted)
# can both reach the API (Service kubernetes, ClusterIP:443, backed by the endpoint of the control plane).

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="api-restrict"
ensure_namespace "$NS"
kubectl delete networkpolicy --all -n "$NS" >/dev/null 2>&1
kubectl delete pod admin-pod restricted-pod -n "$NS" --ignore-not-found --now >/dev/null 2>&1

for role in admin restricted; do
  kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${role}-pod
  namespace: ${NS}
  labels:
    role: ${role}
spec:
  automountServiceAccountToken: false
  containers:
  - name: client
    image: curlimages/curl:8.10.1
    command: ["sh", "-c", "exec sleep 2147483647"]
EOF
done
kubectl wait --for=condition=Ready pod/admin-pod pod/restricted-pod -n "$NS" --timeout=180s >/dev/null 2>&1 || { echo "WARNING: the client Pods are not ready"; exit 1; }

# both clients must reach the API at the start (otherwise the exercise cannot be solved or judged)
CLUSTER_IP=$(kubectl get service kubernetes -n default -o jsonpath='{.spec.clusterIP}')
for pod in admin-pod restricted-pod; do
  CODE=$(kubectl exec -n "$NS" "$pod" -- curl -ks --connect-timeout 4 --max-time 8 -o /dev/null -w '%{http_code}' "https://$CLUSTER_IP:443/version" 2>/dev/null)
  [ -n "$CODE" ] && [ "$CODE" != "000" ] || { echo "WARNING: $pod cannot reach the API at the start"; exit 1; }
done

echo "Setup completed for MHagou-005 Question 8 (namespace '$NS')"
exit 0
