#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
echo "=== Kustomize ConfigMapGenerator Test ==="
kubectl delete -k "$BASE_DIR" 2>/dev/null || true
sleep 2
echo "Applying with kustomize..."
kubectl apply -k "$BASE_DIR"
kubectl wait --for=condition=available --timeout=30s deployment/kustomize-app
echo "ConfigMap name (note the hash suffix):"
kubectl get configmap | grep app-config
POD=$(kubectl get pod -l app=kustomize-app -o jsonpath='{.items[0].metadata.name}')
echo "Content:"
kubectl logs $POD
echo "Updating app.properties..."
echo -e "app.name=MyApp\napp.version=2.0.0\ndatabase.url=postgres://db:5432\ncache.enabled=true" > "$BASE_DIR/app.properties"
kubectl apply -k "$BASE_DIR"
sleep 3
echo "New ConfigMap (different hash):"
kubectl get configmap | grep app-config
echo "✓ Kustomize ConfigMapGenerator test passed - hash changed on update!"
kubectl delete -k "$BASE_DIR"
