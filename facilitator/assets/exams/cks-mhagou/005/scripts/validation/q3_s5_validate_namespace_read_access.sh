#!/bin/bash
# Behaviour: pss-viewer can read the Namespace api-security (labels included) and nothing wider.
# The read is a real request made as the ServiceAccount (impersonation); the rest uses can-i
# (a namespaced Role is evaluated in the namespace of the request: -n api-security).

WHO="system:serviceaccount:api-security:pss-viewer"
can() { kubectl auth can-i "$@" --as="$WHO" -n api-security 2>/dev/null | tail -1; }

kubectl get serviceaccount pss-viewer -n api-security >/dev/null 2>&1 || { echo "❌ ServiceAccount pss-viewer does not exist"; exit 1; }
kubectl get namespace api-security -o name --as="$WHO" >/dev/null 2>&1 || { echo "❌ pss-viewer cannot read the Namespace api-security (kubectl get namespace api-security --as=$WHO is denied)"; exit 1; }
if kubectl get namespace kube-system -o name --as="$WHO" >/dev/null 2>&1; then
  echo "❌ pss-viewer can read other namespaces: limit the rule to api-security"
  exit 1
fi
for verb in update patch delete; do
  [ "$(can $verb namespace/api-security)" = "no" ] || { echo "❌ pss-viewer can $verb the namespace: read access only"; exit 1; }
done
[ "$(can get secrets)" = "no" ] || { echo "❌ pss-viewer can read secrets: the task only asks for the Namespace"; exit 1; }

echo "✅ pss-viewer can read the Namespace api-security and nothing wider"
exit 0
