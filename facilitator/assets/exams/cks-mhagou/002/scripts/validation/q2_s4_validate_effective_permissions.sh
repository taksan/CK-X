#!/bin/bash
# Effective permissions of seminar-sa in seminar: create and update on pods and deployments, nothing else

NS="seminar"
WHO="system:serviceaccount:$NS:seminar-sa"
can() { kubectl auth can-i "$1" "$2" --as="$WHO" -n "$NS" 2>/dev/null; }

[ -n "$(kubectl get serviceaccount seminar-sa -n "$NS" -o name 2>/dev/null)" ] || { echo "❌ ServiceAccount 'seminar-sa' not found"; exit 1; }

for res in pods deployments.apps; do
  for verb in create update; do
    [ "$(can $verb $res)" = "yes" ] || { echo "❌ seminar-sa cannot $verb $res in $NS"; exit 1; }
  done
  for verb in get list delete patch watch; do
    [ "$(can $verb $res)" = "no" ] || { echo "❌ seminar-sa can also $verb $res in $NS: only create and update are allowed"; exit 1; }
  done
done
[ "$(can create secrets)" = "no" ] || { echo "❌ seminar-sa can create secrets"; exit 1; }
[ "$(kubectl auth can-i create pods --as="$WHO" -n kube-system 2>/dev/null)" = "no" ] || { echo "❌ seminar-sa can create pods outside its namespace"; exit 1; }

echo "✅ seminar-sa can create and update pods and deployments in seminar, and nothing else"
exit 0
