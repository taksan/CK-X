#!/bin/bash

# Prior setup for CKS-002: install Istio control plane with Helm if not already installed

NAMESPACE="istio-system"
RELEASE_BASE="istio-base"
RELEASE_ISTIOD="istiod"
ISTIO_REPO_NAME="istio"
ISTIO_REPO_URL="https://istio-release.storage.googleapis.com/charts"

# If istiod deployment already exists, assume Istio is installed
if kubectl get deployment "$RELEASE_ISTIOD" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "Istio control plane already installed in namespace '$NAMESPACE'"
  exit 0
fi

# Ensure Helm is available
if ! command -v helm >/dev/null 2>&1; then
  echo "Helm not found in PATH. Please install Helm and Istio Helm charts before running this lab."
  exit 1
fi

# Add Istio Helm repo if not present
if ! helm repo list | awk 'NR>1 {print $1}' | grep -qx "$ISTIO_REPO_NAME"; then
  echo "Adding Istio Helm repository..."
  helm repo add "$ISTIO_REPO_NAME" "$ISTIO_REPO_URL"
fi

echo "Updating Helm repositories..."
helm repo update >/dev/null 2>&1 || true

# Ensure namespace exists
kubectl create namespace "$NAMESPACE" >/dev/null 2>&1 || true

# Install base chart if not already installed
if ! helm -n "$NAMESPACE" ls --short | grep -qx "$RELEASE_BASE"; then
  echo "Installing Istio base chart with Helm..."
  helm install "$RELEASE_BASE" "$ISTIO_REPO_NAME/base" -n "$NAMESPACE"
fi

# Install istiod control plane if not already installed
if ! helm -n "$NAMESPACE" ls --short | grep -qx "$RELEASE_ISTIOD"; then
  echo "Installing istiod control plane with Helm..."
  helm install "$RELEASE_ISTIOD" "$ISTIO_REPO_NAME/istiod" -n "$NAMESPACE" --wait
fi

echo "Istio control plane installation via Helm completed."
exit 0
