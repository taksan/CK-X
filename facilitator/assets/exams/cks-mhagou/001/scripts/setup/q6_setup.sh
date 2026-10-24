#!/bin/bash

# Setup for MHagou-001 Question 6: encryption of Secrets at rest.
# The candidate puts a key into /etc/kubernetes/etcd-encryption.yaml on the control plane and wires it into the
# kube-apiserver; the node restore removes both. Namespace enc-probe is only used by the validators
# (they create and delete a probe Secret there).

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace enc-probe

# the EncryptionConfiguration with a placeholder for the key, where the question needs it (the node restore removes it)
ssh -o StrictHostKeyChecking=no k8s-api-server 'cat > /etc/kubernetes/etcd-encryption.yaml' <<'YAML'
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <YOUR_BASE64_STRING_HERE>
      - identity: {}
YAML

echo "Setup completed for MHagou-001 Question 6 (probe namespace enc-probe)"
exit 0
