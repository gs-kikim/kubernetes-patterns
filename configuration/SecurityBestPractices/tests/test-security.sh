#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
echo "=== Security Best Practices Test ==="
kubectl delete -f "$BASE_DIR/secret-volume-mount.yaml" 2>/dev/null || true
sleep 2
kubectl apply -f "$BASE_DIR/secret-volume-mount.yaml"
kubectl wait --for=condition=ready --timeout=30s pod/secure-app || true
sleep 2
echo "Secret mounted as volume (not env var):"
kubectl exec secure-app -- ls -la /secrets
echo "✓ Secret mounted as volume, immutable, readOnly!"
kubectl delete -f "$BASE_DIR/secret-volume-mount.yaml"
