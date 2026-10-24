#!/bin/bash
# Source this file: sets INGRESS_IP, INGRESS_HTTP and INGRESS_HTTPS to reach the ingress
# controller of the cluster (Traefik, or ingress-nginx). The LoadBalancer address of the
# controller Service is used; a node address and the node ports are the fallback.

# settings of an external cluster whose ingress/nodes need special care (written by a lane script)
[ -f /home/candidate/.ssh/ckx-lane.env ] && . /home/candidate/.ssh/ckx-lane.env

# CKX_INGRESS_IP, CKX_INGRESS_HTTP and CKX_INGRESS_HTTPS override the discovery (a test lane whose
# ingress is only reachable through a tunnel sets them, for example 127.0.0.1 and the local ports).

if [ -n "${CKX_INGRESS_IP:-}" ] && [ -n "${CKX_INGRESS_HTTP:-}" ]; then
  INGRESS_IP="$CKX_INGRESS_IP"; INGRESS_HTTP="$CKX_INGRESS_HTTP"; INGRESS_HTTPS="${CKX_INGRESS_HTTPS:-443}"
  return 0 2>/dev/null || true
fi

INGRESS_IP=""; INGRESS_HTTP=""; INGRESS_HTTPS=""
for candidate in "traefik traefik" "ingress-nginx ingress-nginx-controller"; do
  set -- $candidate
  IP=$(kubectl get svc "$2" -n "$1" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
  if [ -n "$IP" ]; then
    INGRESS_IP="$IP"; INGRESS_HTTP=80; INGRESS_HTTPS=443
    break
  fi
  HTTP=$(kubectl get svc "$2" -n "$1" -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}' 2>/dev/null)
  HTTPS=$(kubectl get svc "$2" -n "$1" -o jsonpath='{.spec.ports[?(@.port==443)].nodePort}' 2>/dev/null)
  if [ -n "$HTTP" ] && [ -n "$HTTPS" ]; then
    INGRESS_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
    INGRESS_HTTP="$HTTP"; INGRESS_HTTPS="$HTTPS"
    break
  fi
done
