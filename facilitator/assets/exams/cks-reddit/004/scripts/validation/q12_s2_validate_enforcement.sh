#!/bin/bash
# Validate by behaviour: in volume-lab only PVC volumes are accepted; open-volumes is unaffected

pod() { # name volume-yaml
  cat <<EOF
apiVersion: v1
kind: Pod
metadata: {name: $1}
spec:
  containers: [{name: c, image: busybox:1.36.1, command: [sleep, "60"]}]
$2
EOF
}
SECRET_POD=$(pod p1 "  volumes: [{name: v, secret: {secretName: x}}]")
EMPTY_POD=$(pod p2 "  volumes: [{name: v, emptyDir: {}}]")
PVC_POD=$(pod p3 "  volumes: [{name: v, persistentVolumeClaim: {claimName: data}}]")
PLAIN_POD=$(pod p4 "")

try() { echo "$2" | kubectl create -n "$1" --dry-run=server -f - 2>&1; }

for i in $(seq 1 10); do
  OUT=$(try volume-lab "$SECRET_POD")
  echo "$OUT" | grep -qi "denied\|forbidden\|prevent-volume" && break
  sleep 3
done

if ! echo "$OUT" | grep -qi "denied\|forbidden"; then
  echo "❌ A Pod with a Secret volume was accepted in volume-lab"
  exit 1
fi
try volume-lab "$EMPTY_POD" | grep -qi "denied\|forbidden" || { echo "❌ A Pod with an emptyDir volume was accepted in volume-lab"; exit 1; }
try volume-lab "$PVC_POD" | grep -qi "denied\|forbidden" && { echo "❌ A Pod with a PVC volume is rejected in volume-lab"; exit 1; }
try volume-lab "$PLAIN_POD" | grep -qi "denied\|forbidden" && { echo "❌ A Pod without volumes is rejected in volume-lab (the injected service account token volume must be allowed)"; exit 1; }
try open-volumes "$SECRET_POD" | grep -qi "denied\|forbidden" && { echo "❌ The policy also affects the namespace open-volumes"; exit 1; }

echo "✅ volume-lab only accepts PVC volumes; open-volumes is unaffected"
exit 0
