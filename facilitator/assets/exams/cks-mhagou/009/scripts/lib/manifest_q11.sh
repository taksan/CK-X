#!/bin/bash
# Source this file (question 11): loads the Pod manifest of the candidate as JSON (M_JSON)
M_FILE="${Q11_MANIFEST:-/tmp/exam/mhagou-009-q11/deployment.yaml}"
load_manifest() {
  [ -f "$M_FILE" ] || { echo "❌ $M_FILE does not exist"; return 1; }
  M_JSON=$(kubectl create --dry-run=client -o json -f "$M_FILE" 2>/dev/null)
  [ -n "$M_JSON" ] || { echo "❌ $M_FILE is not a valid manifest"; return 1; }
}
