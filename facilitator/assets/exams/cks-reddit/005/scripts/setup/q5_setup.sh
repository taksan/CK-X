#!/bin/bash

# Setup for CKS-005 Question 5: verify image signatures with cosign and pin the verified image by
# digest. Files on the jumphost plus the lab registry (shared infrastructure, repository "payments").
#
# Three tags of the repository: one signed with the trusted key, one signed with ANOTHER key and one
# not signed at all. The roles are shuffled on every run. The private keys are deleted after signing.

source "$(dirname "$0")/../lib/wait-cluster.sh"
source "$(dirname "$0")/../lib/registry.sh"

WORKDIR="/tmp/exam/cks-005-q5"
mkdir -p "${WORKDIR:?}"
rm -rf "${WORKDIR:?}"/* "${WORKDIR:?}"/.state
KEYS=$(mktemp -d)

ensure_registry || { echo "WARNING: the lab registry is not reachable"; exit 1; }

TAGS=($(printf '%s\n' v1.0 v1.1 v1.2 | shuf))
TRUSTED_TAG="${TAGS[0]}"; OTHER_TAG="${TAGS[1]}"; UNSIGNED_TAG="${TAGS[2]}"

(cd "$KEYS" && COSIGN_PASSWORD="" cosign generate-key-pair >/dev/null 2>&1 && mv cosign.key trusted.key && mv cosign.pub trusted.pub \
  && COSIGN_PASSWORD="" cosign generate-key-pair >/dev/null 2>&1 && mv cosign.key other.key && rm -f cosign.pub)

i=0
for src in busybox:1.36.1 busybox:1.36.0 busybox:1.35.0; do
  tag=$(printf '%s\n' v1.0 v1.1 v1.2 | sed -n "$((i+1))p"); i=$((i+1))
  cosign copy --platform linux/amd64 "$src" "$REGISTRY/payments:$tag" >/dev/null 2>&1 || { echo "WARNING: unable to copy $src"; exit 1; }
done

sign() { # key tag
  local d; d=$(registry_digest payments "$2")
  COSIGN_PASSWORD="" cosign sign --yes --tlog-upload=false --key "$KEYS/$1" "$REGISTRY/payments@$d" >/dev/null 2>&1
}
sign trusted.key "$TRUSTED_TAG" || { echo "WARNING: signing failed"; exit 1; }
sign other.key "$OTHER_TAG" || { echo "WARNING: signing failed"; exit 1; }

cp "$KEYS/trusted.pub" "$WORKDIR/cosign.pub"
rm -rf "$KEYS"
echo "$REGISTRY" > "$WORKDIR/registry.txt"
cat > "$WORKDIR/.state" <<EOF
TRUSTED_TAG=$TRUSTED_TAG
TRUSTED_DIGEST=$(registry_digest payments "$TRUSTED_TAG")
REGISTRY=$REGISTRY
EOF

cat > "$WORKDIR/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments
  labels:
    app: payments
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payments
  template:
    metadata:
      labels:
        app: payments
    spec:
      containers:
      - name: payments
        image: ${REGISTRY}/payments:v1.2
        command: ["sleep", "86400"]
EOF

echo "Setup completed for CKS-005 Question 5 (registry $REGISTRY, files in $WORKDIR)"
exit 0
