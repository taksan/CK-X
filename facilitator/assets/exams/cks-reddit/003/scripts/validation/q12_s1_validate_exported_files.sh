#!/bin/bash
# Validate the fields of the existing secret admin were stored in username.txt and password.txt

NS="safe"
DIR="${Q12_DIR:-/tmp/exam/cks-003-q12}"

for field in username password; do
  EXPECTED=$(kubectl get secret admin -n "$NS" -o jsonpath="{.data.$field}" 2>/dev/null | base64 -d)
  if [ -z "$EXPECTED" ]; then
    echo "❌ Secret 'admin' (or its field '$field') not found in namespace '$NS'"
    exit 1
  fi
  if [ ! -f "$DIR/$field.txt" ]; then
    echo "❌ $DIR/$field.txt does not exist"
    exit 1
  fi
  ACTUAL=$(tr -d '\r' < "$DIR/$field.txt" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')
  if [ "$ACTUAL" != "$EXPECTED" ]; then
    echo "❌ $DIR/$field.txt does not contain the decoded '$field' of the secret admin"
    exit 1
  fi
done

echo "✅ username.txt and password.txt contain the decoded values of the secret admin"
exit 0
