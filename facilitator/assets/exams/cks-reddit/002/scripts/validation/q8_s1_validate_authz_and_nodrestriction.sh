#!/bin/bash
# Validate kube-apiserver: authorization mode Node,RBAC and the NodeRestriction admission plugin

CMD=$(kubectl get pods -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null || true)
if [ -z "$CMD" ]; then
  echo "❌ Unable to retrieve the kube-apiserver command from the kube-system namespace"
  exit 1
fi

if ! echo "$CMD" | grep -q -- '--authorization-mode=Node,RBAC'; then
  echo "❌ kube-apiserver is not using --authorization-mode=Node,RBAC"
  exit 1
fi

if ! echo "$CMD" | grep -Eq -- '--enable-admission-plugins=[^"]*NodeRestriction'; then
  echo "❌ kube-apiserver does not have NodeRestriction enabled in --enable-admission-plugins"
  exit 1
fi

echo "✅ kube-apiserver uses Node,RBAC authorization and the NodeRestriction admission plugin"
exit 0
