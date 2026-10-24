#!/bin/bash
# Item: the API server stays healthy: the health endpoints that the kubelet probes without credentials still
# answer 200, the kube-apiserver Pod stays Ready and authenticated requests work.
# Credited only together with the change (the fresh state is healthy too)

SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)
[ -n "$SERVER" ] || { echo "❌ Unable to read the API server address from the kubeconfig"; exit 1; }
code() { curl -sk --noproxy '*' -m 5 -o /dev/null -w '%{http_code}' "$SERVER$1" 2>/dev/null; }

for i in $(seq 1 30); do
  [ "$(code /api)" = "401" ] && break
  sleep 4
done
[ "$(code /api)" = "401" ] || { echo "❌ Anonymous requests to /api are not rejected yet: nothing to credit"; exit 1; }

for path in /livez /readyz; do
  c=$(code "$path")
  [ "$c" = "200" ] || { echo "❌ GET $path without credentials returned HTTP ${c:-none}, expected 200: the kubelet probes it without credentials and will restart the API server"; exit 1; }
done

good=0
for i in $(seq 1 30); do
  if kubectl get --raw /readyz >/dev/null 2>&1 \
     && [ "$(kubectl get pods -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)" = "true" ]; then
    good=$((good + 1))
    [ "$good" -ge 4 ] && break
  else
    good=0
  fi
  sleep 5
done
[ "$good" -ge 4 ] || { echo "❌ The kube-apiserver Pod is not stably Ready (the kubelet probes are failing: check the health endpoints)"; exit 1; }

kubectl get --raw /api/v1/namespaces/kube-system >/dev/null 2>&1 || { echo "❌ Authenticated requests fail"; exit 1; }

echo "✅ The health endpoints answer, the kube-apiserver stays Ready and authenticated requests work"
exit 0
