#!/bin/bash
# Validate an Ingress of the Traefik class routes lab.example.com/reports (or /reports/) to Service reports:80

NS="traefik-lab"
J=$(kubectl get ingress -n "$NS" -o json 2>/dev/null)
echo "$J" | jq -e '[.items[] | select((.spec.ingressClassName // "traefik") == "traefik")
  | .spec.rules[]? | select(.host == "lab.example.com") | .http.paths[]?
  | select((.path == "/reports" or .path == "/reports/") and .backend.service.name == "reports" and .backend.service.port.number == 80)] | length > 0' >/dev/null \
  || { echo "❌ No Ingress of the class traefik routes the host lab.example.com, path /reports to Service reports on port 80"; exit 1; }

echo "✅ An Ingress routes lab.example.com/reports to Service reports"
exit 0
