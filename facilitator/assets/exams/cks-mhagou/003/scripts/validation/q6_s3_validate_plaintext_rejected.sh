#!/bin/bash
# Validate by behaviour: a client without a sidecar (mesh-plain) cannot reach helloworld over plaintext
# (the service itself must still run with its proxy)

READY=$(kubectl get pods -n hello-mesh -l app=helloworld -o json 2>/dev/null | jq -r '[.items[] | select(.metadata.deletionTimestamp == null) | ([.status.containerStatuses[]?, .status.initContainerStatuses[]?] | map(select(.name == "istio-proxy")) | .[0].ready) // false] | any')
[ "$READY" = "true" ] || { echo "❌ helloworld has no ready istio-proxy sidecar"; exit 1; }

# credited only when a STRICT policy applies to helloworld (the mesh root or its own namespace):
# without it a failing request would only prove that the service is unreachable
STRICT=$( { kubectl get peerauthentication -n istio-system -o json; kubectl get peerauthentication -n hello-mesh -o json; } 2>/dev/null \
  | jq -s '[.[].items[]? | select(.spec.mtls.mode == "STRICT")] | length')
[ "${STRICT:-0}" -ge 1 ] || { echo "❌ No PeerAuthentication with mtls mode STRICT applies to helloworld yet: nothing to credit"; exit 1; }

[ "$(kubectl get pod plain -n mesh-plain -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ] \
  || { echo "❌ The plain client Pod 'plain' of the namespace mesh-plain (needed by the check) is not running"; exit 1; }
# the plain client can reach the cluster DNS and the Service address (the failure below is not a broken client)
kubectl exec -n mesh-plain plain -- nslookup helloworld.hello-mesh.svc.cluster.local >/dev/null 2>&1 \
  || kubectl exec -n mesh-plain plain -- getent hosts helloworld.hello-mesh.svc.cluster.local >/dev/null 2>&1 \
  || { echo "❌ The plain client cannot resolve the helloworld Service"; exit 1; }

code() { kubectl exec -n mesh-plain plain -- curl -s -o /dev/null -m 5 -w '%{http_code}' http://helloworld.hello-mesh.svc.cluster.local:5000/hello 2>/dev/null; }

# a policy takes a few seconds to reach the proxies
for i in $(seq 1 15); do
  C=$(code)
  [ "$C" != "200" ] && break
  sleep 3
done

if [ "$C" = "200" ]; then
  echo "❌ The plain client (no sidecar) still reaches helloworld over plaintext (HTTP 200): mTLS is not STRICT"
  exit 1
fi

echo "✅ Plaintext requests from a client without a sidecar are rejected (HTTP ${C:-connection reset})"
exit 0
