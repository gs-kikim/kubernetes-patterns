#!/bin/bash
# Network Segmentation Lab - Calico CNI Setup Script
# This script sets up a minikube cluster with Calico CNI for NetworkPolicy testing

set -e

echo "=== Network Segmentation Lab - Calico CNI Setup ==="
echo ""

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "Error: minikube is not installed. Please install minikube first."
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Delete existing minikube cluster if exists
echo "[1/5] Cleaning up existing minikube cluster..."
minikube delete 2>/dev/null || true

# Start minikube with Calico CNI
echo "[2/5] Starting minikube with Calico CNI..."
minikube start --cni=calico --memory=4096 --cpus=2

# Wait for Calico to be ready
echo "[3/5] Waiting for Calico pods to be ready..."
kubectl wait --for=condition=Ready pods -l k8s-app=calico-node -n kube-system --timeout=300s
kubectl wait --for=condition=Ready pods -l k8s-app=calico-kube-controllers -n kube-system --timeout=300s

# Verify Calico installation
echo "[4/5] Verifying Calico installation..."
kubectl get pods -n kube-system | grep calico

# Create namespaces
echo "[5/5] Creating namespaces..."
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace production name=production environment=prod --overwrite

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace monitoring name=monitoring --overwrite

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Calico CNI is installed and ready."
echo "Namespaces created: production, monitoring"
echo ""
echo "Next steps:"
echo "  1. Deploy test application: kubectl apply -f 05-3tier-app-deployment.yaml"
echo "  2. Run connectivity tests: ./test-connectivity.sh before"
echo "  3. Apply NetworkPolicies and test"
echo ""
