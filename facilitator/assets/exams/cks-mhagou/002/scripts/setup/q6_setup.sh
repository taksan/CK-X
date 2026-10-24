#!/bin/bash

# Setup for MHAGOU-002 Question 6: a gVisor RuntimeClass. Namespace sandbox-test is exclusive.
# The cluster already has a RuntimeClass "gvisor": the question uses another name (runsc-class,
# cluster scoped, deleted by the session cleanup) so that nothing is credited before the candidate acts.

source "$(dirname "$0")/../lib/wait-cluster.sh"

NS="sandbox-test"
ensure_namespace "$NS"
kubectl delete pod gvisor-pod -n "$NS" --ignore-not-found --now >/dev/null 2>&1
kubectl delete runtimeclass runsc-class --ignore-not-found >/dev/null 2>&1

echo "Setup completed for MHAGOU-002 Question 6 (namespace '$NS')"
exit 0
