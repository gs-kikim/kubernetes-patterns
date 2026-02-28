#!/bin/bash

# Cleanup script for RBAC Access Control Pattern tests

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Cleaning up RBAC test resources..."

kubectl delete -f "$SCRIPT_DIR/" --ignore-not-found=true 2>/dev/null || true
kubectl delete clusterrolebinding app-sa-view-nodes --ignore-not-found=true 2>/dev/null || true
kubectl delete clusterrole view-pods view-nodes --ignore-not-found=true 2>/dev/null || true
kubectl delete namespace rbac-test rbac-test-2 --ignore-not-found=true 2>/dev/null || true

echo "Cleanup completed!"
