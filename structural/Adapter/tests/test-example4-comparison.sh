#!/bin/bash
# Compare Traditional vs Native Sidecar behavior

set -e

EXAMPLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../example4-native-sidecar" && pwd)"
cd "$EXAMPLE_DIR"

echo "=========================================================="
echo "Example 4: Traditional vs Native Sidecar Comparison"
echo "=========================================================="
echo ""

# Build images
echo "Building images..."
docker build -t k8spatterns/batch-job:1.0 -f Dockerfile.job . > /dev/null
docker build -t k8spatterns/metrics-adapter:1.0 -f Dockerfile.adapter . > /dev/null

echo ""
echo "========================================="
echo "Test 1: Traditional Sidecar (Problem)"
echo "========================================="

kubectl apply -f job-traditional.yaml

echo "Waiting for job to process..."
sleep 30

echo ""
echo "Job status:"
kubectl get job batch-job-traditional

echo ""
echo "Pod status:"
kubectl get pods -l type=traditional

echo ""
echo "Main container log (last 10 lines):"
kubectl logs -l type=traditional -c batch-processor --tail=10

echo ""
echo "Adapter container status:"
kubectl logs -l type=traditional -c metrics-adapter --tail=5

echo ""
echo "✗ Notice: Main container completed, but Pod is still Running!"
echo "  This is the problem with traditional sidecars in Jobs."

kubectl delete -f job-traditional.yaml
sleep 5

echo ""
echo "========================================="
echo "Test 2: Native Sidecar (Solution)"
echo "========================================="

# Check Kubernetes version
K8S_VERSION=$(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}')
echo "Kubernetes version: $K8S_VERSION"

kubectl apply -f job-native-sidecar.yaml

echo "Waiting for job to complete..."
sleep 30

echo ""
echo "Job status:"
kubectl get job batch-job-native-sidecar

echo ""
echo "Pod status:"
kubectl get pods -l type=native-sidecar

echo ""
echo "Main container log (last 10 lines):"
kubectl logs -l type=native-sidecar -c batch-processor --tail=10 || true

echo ""
echo "Adapter container log (last 5 lines):"
kubectl logs -l type=native-sidecar -c metrics-adapter --tail=5 || true

JOB_STATUS=$(kubectl get job batch-job-native-sidecar -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}')

if [ "$JOB_STATUS" == "True" ]; then
    echo ""
    echo "✓ Success: Job completed and Pod terminated properly!"
    echo "  This is the benefit of Native Sidecar."
else
    echo ""
    echo "⚠ Job not completed yet, but will complete soon."
fi

kubectl delete -f job-native-sidecar.yaml

echo ""
echo "========================================="
echo "Comparison Summary"
echo "========================================="
echo ""
echo "Traditional Sidecar:"
echo "  ✗ Main container completes"
echo "  ✗ Sidecar keeps running"
echo "  ✗ Pod never terminates"
echo "  ✗ Job never completes"
echo ""
echo "Native Sidecar:"
echo "  ✓ Sidecar starts first (with startupProbe)"
echo "  ✓ Main container starts after sidecar ready"
echo "  ✓ Main container completes"
echo "  ✓ Sidecar terminates automatically"
echo "  ✓ Pod terminates properly"
echo "  ✓ Job completes successfully"
echo ""
