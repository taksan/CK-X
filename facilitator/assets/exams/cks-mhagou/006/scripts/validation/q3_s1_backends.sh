#!/bin/bash
# The nginx backends of asia and europe: 2 ready replicas and a Service on port 80 with ready endpoints
# that belong to the Deployment (a declared containerPort is not required: nginx listens on 80 anyway)

for ns in asia europe; do
  D=$(kubectl get deployments -n "$ns" -o json 2>/dev/null | jq -c '[.items[] | select(.spec.replicas == 2 and ((.status.readyReplicas // 0) == 2) and any(.spec.template.spec.containers[]; (.image | test("nginx"))))] | first // empty')
  [ -n "$D" ] || { echo "❌ Namespace $ns has no nginx Deployment with exactly 2 ready replicas"; exit 1; }
  SEL=$(echo "$D" | jq -c '.spec.selector.matchLabels')
  SVC=$(kubectl get svc -n "$ns" -o json 2>/dev/null | jq -c --argjson sel "$SEL" '[.items[] | select(.spec.type != "ExternalName" and any(.spec.ports[]; .port == 80) and (.spec.selector != null) and ((.spec.selector | to_entries) | all(. as $e | $sel[$e.key] == $e.value)))] | first // empty')
  [ -n "$SVC" ] || { echo "❌ Namespace $ns has no Service on port 80 that selects the Pods of the nginx Deployment"; exit 1; }
  NAME=$(echo "$SVC" | jq -r '.metadata.name')
  READY=$(kubectl get endpointslices -n "$ns" -l "kubernetes.io/service-name=$NAME" -o json 2>/dev/null | jq '[.items[].endpoints[]? | select(.conditions.ready == true)] | length')
  [ "${READY:-0}" -ge 2 ] || { echo "❌ Service '$NAME' of namespace $ns has ${READY:-0} ready endpoints, expected 2"; exit 1; }
done

echo "✅ The nginx backends of asia and europe are ready behind Services on port 80"
exit 0
