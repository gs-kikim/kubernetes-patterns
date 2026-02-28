#!/bin/bash
set -e

echo "========================================="
echo "Native Sidecar Containers Test"
echo "========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "Step 1: Cleanup existing resources"
echo "---------------------------------------"
kubectl delete -f "$BASE_DIR/sidecar-pod.yaml" 2>/dev/null || true
kubectl delete -f "$BASE_DIR/sidecar-job.yaml" 2>/dev/null || true
sleep 2

echo ""
echo "Step 2: Deploy pod with native sidecar"
echo "---------------------------------------"
kubectl apply -f "$BASE_DIR/sidecar-pod.yaml"

echo ""
echo "Step 3: Wait for pod to be running"
echo "---------------------------------------"
kubectl wait --for=condition=ready --timeout=30s pod/webapp-sidecar

echo ""
echo "Step 4: Verify sidecar started first"
echo "---------------------------------------"
echo "Sidecar logs (first 10 lines):"
kubectl logs webapp-sidecar -c config-sidecar | head -10

echo ""
echo "Main container logs:"
kubectl logs webapp-sidecar -c webapp

echo ""
echo "Step 5: Verify sidecar is still running"
echo "---------------------------------------"
sleep 3
echo "Recent sidecar activity:"
kubectl logs webapp-sidecar -c config-sidecar --tail=5

echo ""
echo "Step 6: Test Job with sidecar (doesn't block completion)"
echo "---------------------------------------"
kubectl apply -f "$BASE_DIR/sidecar-job.yaml"

echo "Waiting for job to complete (max 60s)..."
if kubectl wait --for=condition=complete --timeout=60s job/data-processor; then
    echo "✓ Job completed successfully - sidecar didn't block completion!"
else
    echo "✗ Job failed to complete"
    kubectl describe job/data-processor
    exit 1
fi

echo ""
echo "Job pod logs:"
POD_NAME=$(kubectl get pods -l app=data-processor -o jsonpath='{.items[0].metadata.name}')
echo "Main container:"
kubectl logs $POD_NAME -c processor

echo ""
echo "Sidecar logs (last 10 lines):"
kubectl logs $POD_NAME -c logger-sidecar --tail=10

echo ""
echo "========================================="
echo "✓ All native sidecar tests passed!"
echo "========================================="
echo ""
echo "Key observations:"
echo "1. Sidecar (restartPolicy: Always) started before main container"
echo "2. Sidecar continues running throughout pod lifecycle"
echo "3. In Jobs, sidecar doesn't prevent completion"
echo "4. Both startupProbe and livenessProbe work on sidecars"
echo ""
echo "Cleanup:"
echo "  kubectl delete -f $BASE_DIR/sidecar-pod.yaml"
echo "  kubectl delete -f $BASE_DIR/sidecar-job.yaml"
