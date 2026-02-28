#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
echo "=== Projected Volumes Test ==="
kubectl delete -f "$BASE_DIR/projected-pod.yaml" 2>/dev/null || true
sleep 2
kubectl apply -f "$BASE_DIR/projected-pod.yaml"
kubectl wait --for=condition=ready --timeout=30s pod/projected-demo
echo "Files in projected volume:"
kubectl exec projected-demo -- ls -la /config
echo ""
echo "ConfigMap content:"
kubectl exec projected-demo -- cat /config/app.conf
echo ""
echo "Secret content (db-password):"
kubectl exec projected-demo -- cat /config/db-password
echo ""
echo "DownwardAPI content:"
kubectl exec projected-demo -- cat /config/pod-name
echo "✓ Projected volumes test passed!"
kubectl delete -f "$BASE_DIR/projected-pod.yaml"
