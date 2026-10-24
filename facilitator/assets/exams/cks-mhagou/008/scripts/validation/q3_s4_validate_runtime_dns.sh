#!/bin/bash
# Item: with the policy in force DNS names still resolve from the Pods of threat-prevention.
# The policy must exist and select the Pods (otherwise there is nothing to credit).
# (Pod-to-Pod traffic is deliberately not tested: with Cilium an ipBlock rule never matches the
# IP addresses of Pods of the cluster, whatever the CNI of the exam environment does.)

NS="threat-prevention"

SEL=$(kubectl get networkpolicy block-malicious-egress -n "$NS" -o json 2>/dev/null | jq -r '(.spec.podSelector // {}) | ((.matchLabels // {} | length) + (.matchExpressions // [] | length))')
[ -n "$SEL" ] || { echo "❌ NetworkPolicy 'block-malicious-egress' not found in namespace '$NS'"; exit 1; }
[ "$SEL" = "0" ] || { echo "❌ The policy does not select all the Pods: the runtime test is not meaningful"; exit 1; }

# the policy takes a few seconds to be enforced: give it time, then judge both Pods
for i in $(seq 1 10); do
  kubectl exec -n "$NS" lab-client -- nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1 && break
  sleep 3
done

for pod in lab-client lab-peer; do
  kubectl exec -n "$NS" "$pod" -- nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1 \
    || { echo "❌ DNS resolution does not work from $pod with the policy in force: the DNS exception (UDP/TCP 53 to any destination) is missing or too narrow"; exit 1; }
done

echo "✅ DNS names resolve from the Pods with the policy in force"
exit 0
