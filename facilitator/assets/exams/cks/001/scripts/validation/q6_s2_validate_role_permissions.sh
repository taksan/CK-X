#!/bin/bash
# Validate that the Role has correct permissions

ROLE_NAME="app-reader-role"
NAMESPACE="rbac-minimize"
ALLOWED_RESOURCES=("pods" "services" "deployments")
FORBIDDEN_RESOURCES=("secrets" "configmaps")
ALLOWED_VERBS=("get" "list")
FORBIDDEN_VERBS=("create" "update" "delete" "patch")

# Check if role exists
kubectl get role $ROLE_NAME -n $NAMESPACE &> /dev/null
if [ $? -ne 0 ]; then
  echo "❌ Role '$ROLE_NAME' not found in namespace '$NAMESPACE'"
  exit 1
fi

CAN_I="kubectl -n $NAMESPACE auth can-i --as=system:serviceaccount:$NAMESPACE:app-reader"

# Check allowed verbs and resources
for verb in "${ALLOWED_VERBS[@]}"; do
  for resource in "${ALLOWED_RESOURCES[@]}"; do
    if ! $CAN_I $verb $resource > /dev/null 2>&1; then
      echo "❌ Role does not allow '$verb' permission on '$resource'"
      exit 1
    fi
  done
done

# Check forbidden verbs and resources
for verb in "${FORBIDDEN_VERBS[@]}"; do
  for resource in "${ALLOWED_RESOURCES[@]}"; do
    if $CAN_I $verb $resource > /dev/null 2>&1; then
      echo "❌ A reader role should not allow '$verb' permission on '$resource'"
      exit 1
    fi
  done
done

# Check if role does NOT allow access to forbidden resources
for resource in "${FORBIDDEN_RESOURCES[@]}"; do
  if [[ "$RESOURCES" == *"$resource"* ]]; then
    echo "❌ Role allows access to forbidden resource: $resource"
    exit 1
  fi
done

echo "✅ Role has correct minimal permissions"
exit 0 
