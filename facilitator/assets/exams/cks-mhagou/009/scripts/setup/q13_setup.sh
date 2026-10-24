#!/bin/bash

# Setup for MHagou CKS exam 9, Question 13: reject images with the latest tag with a ValidatingAdmissionPolicy.
# (The source question configured a second ImagePolicyWebhook; the API server has a single admission
# configuration file, owned by question 6, so this one uses the native policy mechanism.)
# Namespace registry-gate is exclusive. The policy and its binding (cluster-scoped) are created by the candidate.

source "$(dirname "$0")/../lib/wait-cluster.sh"

ensure_namespace registry-gate
kubectl delete validatingadmissionpolicybinding deny-latest-tag-binding --ignore-not-found >/dev/null 2>&1
kubectl delete validatingadmissionpolicy deny-latest-tag --ignore-not-found >/dev/null 2>&1

echo "Setup completed for MHagou exam 9 Question 13 (namespace registry-gate)"
exit 0
