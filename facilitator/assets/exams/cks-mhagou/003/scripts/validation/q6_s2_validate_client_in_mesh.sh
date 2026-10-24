#!/bin/bash
# Validate the client namespace is part of the mesh: injection enabled, the client Pod has a ready
# Istio proxy (container or native sidecar) and reaches helloworld

NS="mesh-client"
LABELS=$(kubectl get namespace "$NS" -o json 2>/dev/null | jq -c '.metadata.labels // {}')
echo "$LABELS" | jq -e '(.["istio-injection"] == "enabled") or ((.["istio.io/rev"] // "") != "")' >/dev/null \
  || { echo "❌ Sidecar injection is not enabled in namespace '$NS' (label istio-injection=enabled)"; exit 1; }

PODS=$(kubectl get pods -n "$NS" -o json 2>/dev/null | jq -r '.items[] | select(.metadata.deletionTimestamp == null) | select(.status.phase == "Running") | .metadata.name')
[ -n "$PODS" ] || { echo "❌ No running Pod in namespace '$NS'"; exit 1; }

for pod in $PODS; do
  READY=$(kubectl get pod "$pod" -n "$NS" -o json | jq -r '([.status.containerStatuses[]?, .status.initContainerStatuses[]?] | map(select(.name == "istio-proxy")) | .[0].ready) // false')
  if [ "$READY" != "true" ]; then
    echo "❌ Pod $pod has no ready istio-proxy sidecar (injection happens when a Pod is created: restart the Pod after labelling the namespace)"
    exit 1
  fi
  C=""
  for i in $(seq 1 10); do
    C=$(kubectl exec -n "$NS" "$pod" -c curl -- curl -s -o /dev/null -m 5 -w '%{http_code}' http://helloworld.hello-mesh.svc.cluster.local:5000/hello 2>/dev/null)
    [ "$C" = "200" ] && break
    sleep 3
  done
  [ "$C" = "200" ] || { echo "❌ Pod $pod cannot reach helloworld (HTTP ${C:-none}), expected 200"; exit 1; }
done

echo "✅ The client runs with an Istio proxy and reaches helloworld"
exit 0
