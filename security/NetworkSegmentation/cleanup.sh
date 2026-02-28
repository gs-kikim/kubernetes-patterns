#!/bin/bash
# Cleanup Script for Network Segmentation Lab
# Removes all resources created during the lab
#
# Usage:
#   ./cleanup.sh [--delete-cluster]

set -e

NAMESPACE="production"
MONITORING_NAMESPACE="monitoring"

echo "=== Network Segmentation Lab Cleanup ==="
echo ""

# Delete NetworkPolicies
echo "[1/4] Deleting NetworkPolicies..."
kubectl delete networkpolicies --all -n $NAMESPACE 2>/dev/null || true
echo "NetworkPolicies deleted."

# Delete CiliumNetworkPolicies (if Cilium is installed)
echo "[2/4] Deleting CiliumNetworkPolicies (if any)..."
kubectl delete ciliumnetworkpolicies --all -n $NAMESPACE 2>/dev/null || true
echo "CiliumNetworkPolicies deleted."

# Delete Deployments and Services
echo "[3/4] Deleting Deployments and Services..."
kubectl delete deployment --all -n $NAMESPACE 2>/dev/null || true
kubectl delete service --all -n $NAMESPACE 2>/dev/null || true
kubectl delete pods --all -n $NAMESPACE 2>/dev/null || true
echo "Deployments and Services deleted."

# Delete Namespaces
echo "[4/4] Deleting namespaces..."
kubectl delete namespace $NAMESPACE 2>/dev/null || true
kubectl delete namespace $MONITORING_NAMESPACE 2>/dev/null || true
echo "Namespaces deleted."

echo ""
echo "=== Cleanup Complete ==="
echo ""

# Optional: Delete minikube cluster
if [ "$1" = "--delete-cluster" ]; then
    echo "Deleting minikube cluster..."
    minikube delete
    echo "Minikube cluster deleted."
fi

echo "To completely reset, run: minikube delete"
echo ""
