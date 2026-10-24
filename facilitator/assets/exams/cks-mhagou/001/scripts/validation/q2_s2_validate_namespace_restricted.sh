#!/bin/bash
# Item: the namespace secured-area enforces the restricted Pod Security Standard

L=$(kubectl get namespace secured-area -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)
[ "$L" = "restricted" ] || { echo "❌ secured-area is labelled enforce='${L:-none}', expected restricted"; exit 1; }

echo "✅ secured-area enforces the restricted Pod Security Standard"
exit 0
