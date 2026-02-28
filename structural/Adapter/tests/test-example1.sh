#!/bin/bash
# Test Example 1: Basic Prometheus Adapter

set -e

EXAMPLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../example1-basic-prometheus" && pwd)"
cd "$EXAMPLE_DIR"

echo "========================================="
echo "Example 1: Basic Prometheus Adapter Test"
echo "========================================="
echo ""

# Build images
echo "Building images..."
docker build -t k8spatterns/random-generator:1.0 -f Dockerfile.app .
docker build -t k8spatterns/prometheus-adapter:1.0 -f Dockerfile.adapter .

# Deploy
echo ""
echo "Deploying to Kubernetes..."
kubectl apply -f deployment.yaml

# Wait for ready
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=random-generator --timeout=120s

POD=$(kubectl get pods -l app=random-generator -o jsonpath='{.items[0].metadata.name}')
echo "Pod: $POD"

# Port forward
echo ""
echo "Setting up port forwarding..."
kubectl port-forward $POD 8080:8080 > /dev/null 2>&1 &
PF_PID1=$!
kubectl port-forward $POD 9889:9889 > /dev/null 2>&1 &
PF_PID2=$!

sleep 3

# Generate traffic
echo "Generating random numbers..."
for i in {1..10}; do
    curl -s http://localhost:8080/random > /dev/null
    echo "Request $i sent"
    sleep 1
done

# Check metrics
echo ""
echo "Checking Prometheus metrics..."
echo ""
curl http://localhost:9889/metrics | grep random_

# Cleanup
echo ""
echo "Cleaning up..."
kill $PF_PID1 $PF_PID2 2>/dev/null || true
kubectl delete -f deployment.yaml

echo ""
echo "✓ Example 1 test completed successfully"
