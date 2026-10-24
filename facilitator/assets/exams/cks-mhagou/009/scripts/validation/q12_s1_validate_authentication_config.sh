#!/bin/bash
# Item: the kube-apiserver manifest uses an AuthenticationConfiguration file (--authentication-config) that
# disables anonymous access or restricts it to the health endpoints (and no longer has the plain
# --anonymous-auth flag: the two cannot be combined)

CMD=$(ssh -o StrictHostKeyChecking=no k8s-api-server "yq -o=json '.spec.containers[0].command' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null)
[ -n "$CMD" ] || { echo "❌ Unable to read /etc/kubernetes/manifests/kube-apiserver.yaml on k8s-api-server (is the file valid YAML?)"; exit 1; }

FILE=$(echo "$CMD" | jq -r '[.[] | select(startswith("--authentication-config="))] | last // empty | sub("^--authentication-config="; "")')
[ -n "$FILE" ] || { echo "❌ The kube-apiserver manifest has no --authentication-config flag (the plain --anonymous-auth=false flag makes the kubelet probes fail: the structured configuration is needed)"; exit 1; }

echo "$CMD" | jq -e 'any(.[]; startswith("--anonymous-auth"))' >/dev/null \
  && { echo "❌ The manifest still has the --anonymous-auth flag: it cannot be combined with --authentication-config"; exit 1; }

CFG=$(ssh -o StrictHostKeyChecking=no k8s-api-server "yq -o=json '.' '$FILE'" 2>/dev/null)
[ -n "$CFG" ] || { echo "❌ The authentication configuration '$FILE' does not exist on the control plane or is not valid YAML"; exit 1; }
echo "$CFG" | jq -e '.kind == "AuthenticationConfiguration"' >/dev/null || { echo "❌ $FILE is not an AuthenticationConfiguration (kind: AuthenticationConfiguration)"; exit 1; }
echo "$CFG" | jq -e '.anonymous != null' >/dev/null || { echo "❌ $FILE has no 'anonymous' section"; exit 1; }

if echo "$CFG" | jq -e '.anonymous.enabled == true' >/dev/null; then
  echo "$CFG" | jq -e '(.anonymous.conditions // []) | length > 0' >/dev/null \
    || { echo "❌ anonymous is enabled without conditions: every endpoint stays open to unauthenticated requests"; exit 1; }
  BAD=$(echo "$CFG" | jq -r '[.anonymous.conditions[]?.path | select(. != "/livez" and . != "/readyz" and . != "/healthz")] | join(",")')
  [ -z "$BAD" ] || { echo "❌ anonymous access is allowed for more than the health endpoints (conditions: $BAD)"; exit 1; }
fi

echo "✅ The kube-apiserver uses $FILE: anonymous access is disabled or limited to the health endpoints"
exit 0
