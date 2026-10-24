#!/bin/bash
# Behaviour (server-side dry-run): the original insecure Pod (plain nginx) is rejected by Pod
# Security admission in pss-test

OUT=$(kubectl create -n pss-test --dry-run=server -f - 2>&1 <<EOF
apiVersion: v1
kind: Pod
metadata: {name: ckx-original}
spec:
  containers:
  - {name: nginx, image: nginx}
EOF
)
echo "$OUT" | grep -q 'violates PodSecurity "restricted' || { echo "❌ The original Pod is not rejected by the restricted Pod Security policy of pss-test (got: $(echo "$OUT" | head -1 | cut -c1-120))"; exit 1; }

echo "✅ The original insecure Pod is rejected by Pod Security admission"
exit 0
