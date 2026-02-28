#!/bin/bash
set -e

echo "========================================="
echo "Configuration Template Pattern - Basic Test"
echo "========================================="

NAMESPACE="default"
APP_LABEL="app=webapp"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "Step 1: Cleanup any existing resources"
echo "---------------------------------------"
kubectl delete -f "$BASE_DIR/service.yaml" 2>/dev/null || true
kubectl delete -f "$BASE_DIR/deployment.yaml" 2>/dev/null || true
kubectl delete configmap webapp-config 2>/dev/null || true
sleep 2

echo ""
echo "Step 2: Deploy Development Configuration"
echo "---------------------------------------"
kubectl apply -f "$BASE_DIR/dev/configmap-dev.yaml"
kubectl apply -f "$BASE_DIR/deployment.yaml"
kubectl apply -f "$BASE_DIR/service.yaml"

echo ""
echo "Step 3: Wait for deployment to be ready"
echo "---------------------------------------"
kubectl wait --for=condition=available --timeout=120s deployment/webapp

echo ""
echo "Step 4: Get pod information"
echo "---------------------------------------"
POD_NAME=$(kubectl get pod -l $APP_LABEL -o jsonpath='{.items[0].metadata.name}')
echo "Pod name: $POD_NAME"

echo ""
echo "Step 5: Check init container logs"
echo "---------------------------------------"
echo "Template processor logs:"
kubectl logs $POD_NAME -c template-processor

echo ""
echo "Step 6: Verify processed configuration"
echo "---------------------------------------"
echo "Generated index.html (first 30 lines):"
kubectl exec $POD_NAME -- cat /usr/share/nginx/html/index.html | head -30

echo ""
echo "Generated nginx.conf (log format section):"
kubectl exec $POD_NAME -- cat /etc/nginx/nginx.conf | grep -A 3 "log_format"

echo ""
echo "Step 7: Test HTTP endpoint"
echo "---------------------------------------"
NODE_PORT=$(kubectl get svc webapp -o jsonpath='{.spec.ports[0].nodePort}')
MINIKUBE_IP=$(minikube ip)
echo "Service URL: http://$MINIKUBE_IP:$NODE_PORT"

# Test health endpoint
echo "Testing /health endpoint:"
curl -s http://$MINIKUBE_IP:$NODE_PORT/health

echo ""
echo "Testing main page (checking for DEVELOPMENT):"
RESPONSE=$(curl -s http://$MINIKUBE_IP:$NODE_PORT/)
if echo "$RESPONSE" | grep -q "DEVELOPMENT"; then
    echo "✓ Found DEVELOPMENT environment marker"
else
    echo "✗ DEVELOPMENT marker not found!"
    exit 1
fi

if echo "$RESPONSE" | grep -q "DEBUG"; then
    echo "✓ Found DEBUG log level"
else
    echo "✗ DEBUG log level not found!"
    exit 1
fi

echo ""
echo "Step 8: Check nginx access logs"
echo "---------------------------------------"
# Generate some traffic
for i in {1..3}; do
    curl -s http://$MINIKUBE_IP:$NODE_PORT/ > /dev/null
done
sleep 1

echo "Recent access logs (should show DEVELOPMENT prefix):"
kubectl exec $POD_NAME -- tail -5 /var/log/nginx/access.log

echo ""
echo "========================================="
echo "✓ All tests passed!"
echo "========================================="
echo ""
echo "Cleanup (optional):"
echo "  kubectl delete -f $BASE_DIR/service.yaml"
echo "  kubectl delete -f $BASE_DIR/deployment.yaml"
echo "  kubectl delete configmap webapp-config"
