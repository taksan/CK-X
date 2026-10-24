#!/bin/bash
# Ingress world in namespace world: host world.universe.mine, TLS with test-secret, /europe to
# Service europe on port 80. /europe and /europe/ are the same Prefix path for the Kubernetes spec (elements
# are compared, the trailing slash is ignored)

J=$(kubectl get ingress world -n world -o json 2>/dev/null)
[ -n "$J" ] || { echo "❌ Ingress 'world' not found in namespace 'world'"; exit 1; }

echo "$J" | jq -e '[.spec.tls[]? | select(.secretName == "test-secret")] | length > 0' >/dev/null || { echo "❌ The Ingress does not use the TLS secret 'test-secret'"; exit 1; }
echo "$J" | jq -e '[.spec.rules[]? | select(.host == "world.universe.mine") | .http.paths[]? | select((.path == "/europe" or .path == "/europe/") and .backend.service.name == "europe" and .backend.service.port.number == 80)] | length > 0' >/dev/null \
  || { echo "❌ The Ingress does not route world.universe.mine /europe to Service europe on port 80"; exit 1; }

echo "✅ Ingress 'world' routes https://world.universe.mine/europe to Service europe with the TLS secret"
exit 0
