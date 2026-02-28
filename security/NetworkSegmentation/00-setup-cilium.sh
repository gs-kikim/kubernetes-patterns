#!/bin/bash
# Network Segmentation Lab - Cilium CNI Setup Script
# This script sets up a minikube cluster with Cilium CNI for NetworkPolicy testing

set -e

echo "=== Network Segmentation Lab - Cilium CNI Setup ==="
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

# Check if cilium CLI is installed
CILIUM_CLI_INSTALLED=true
if ! command -v cilium &> /dev/null; then
    echo "Warning: Cilium CLI is not installed."
    echo "You can install it with: brew install cilium-cli (macOS) or from https://docs.cilium.io/en/stable/gettings-started/k8s-install-default/"
    CILIUM_CLI_INSTALLED=false
fi

# Delete existing minikube cluster if exists
echo "[1/6] Cleaning up existing minikube cluster..."
minikube delete 2>/dev/null || true

# Start minikube with Cilium CNI
echo "[2/6] Starting minikube with Cilium CNI..."
minikube start --cni=cilium --memory=4096 --cpus=2

# Wait for Cilium to be ready
echo "[3/6] Waiting for Cilium pods to be ready..."
kubectl wait --for=condition=Ready pods -l k8s-app=cilium -n kube-system --timeout=300s

# Verify Cilium installation
echo "[4/6] Verifying Cilium installation..."
kubectl get pods -n kube-system -l k8s-app=cilium

if [ "$CILIUM_CLI_INSTALLED" = true ]; then
    echo ""
    echo "Checking Cilium status with CLI..."
    cilium status --wait
fi

# Enable Hubble (optional but recommended)
echo "[5/6] Enabling Hubble for network observability..."
if [ "$CILIUM_CLI_INSTALLED" = true ]; then
    cilium hubble enable --ui || echo "Note: Hubble UI may require additional configuration"
else
    echo "Skipping Hubble setup (Cilium CLI not installed)"
fi

# Create namespaces
echo "[6/6] Creating namespaces..."
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace production name=production environment=prod --overwrite

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace monitoring name=monitoring --overwrite

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Cilium CNI is installed and ready."
echo "Namespaces created: production, monitoring"
echo ""
echo "Cilium-specific features available:"
echo "  - Standard NetworkPolicy (L3/L4)"
echo "  - CiliumNetworkPolicy (L7 HTTP, DNS-based egress)"
echo "  - Hubble for network observability"
echo ""
echo "Next steps:"
echo "  1. Deploy test application: kubectl apply -f 05-3tier-app-deployment.yaml"
echo "  2. Run connectivity tests: ./test-connectivity.sh before"
echo "  3. Apply NetworkPolicies and test"
echo ""
echo "For Hubble UI:"
echo "  cilium hubble ui"
echo "  Open http://localhost:12000 in your browser"
echo ""
