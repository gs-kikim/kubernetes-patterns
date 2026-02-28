#!/bin/bash
set -e

echo "========================================="
echo "Configuration Template - Environment Switching Test"
echo "========================================="

NAMESPACE="default"
APP_LABEL="app=webapp"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "Step 1: Ensure development environment is running"
echo "---------------------------------------"
kubectl apply -f "$BASE_DIR/dev/configmap-dev.yaml"
kubectl apply -f "$BASE_DIR/deployment.yaml"
kubectl apply -f "$BASE_DIR/service.yaml"
kubectl wait --for=condition=available --timeout=60s deployment/webapp

POD_NAME=$(kubectl get pod -l $APP_LABEL -o jsonpath='{.items[0].metadata.name}')
echo "Current pod: $POD_NAME"

NODE_PORT=$(kubectl get svc webapp -o jsonpath='{.spec.ports[0].nodePort}')
MINIKUBE_IP=$(minikube ip)
echo "Service URL: http://$MINIKUBE_IP:$NODE_PORT"

echo ""
echo "Step 2: Verify development configuration"
echo "---------------------------------------"
RESPONSE=$(curl -s http://$MINIKUBE_IP:$NODE_PORT/)
if echo "$RESPONSE" | grep -q "DEVELOPMENT"; then
    echo "✓ Currently running in DEVELOPMENT mode"
    echo "  - Log Level: DEBUG"
    echo "  - Background Color: Green (#00FF00)"
else
    echo "✗ Not in development mode!"
    exit 1
fi

echo ""
echo "Step 3: Switch to Production Configuration"
echo "---------------------------------------"
echo "Deleting old ConfigMap..."
kubectl delete configmap webapp-config

echo "Creating production ConfigMap..."
kubectl apply -f "$BASE_DIR/prod/configmap-prod.yaml"

echo "Restarting deployment to pick up new config..."
kubectl rollout restart deployment/webapp
kubectl rollout status deployment/webapp --timeout=60s

# Get new pod name
NEW_POD_NAME=$(kubectl get pod -l $APP_LABEL -o jsonpath='{.items[0].metadata.name}')
echo "New pod: $NEW_POD_NAME"

echo ""
echo "Step 4: Verify production configuration"
echo "---------------------------------------"
sleep 3  # Wait for nginx to be ready

RESPONSE=$(curl -s http://$MINIKUBE_IP:$NODE_PORT/)
if echo "$RESPONSE" | grep -q "PRODUCTION"; then
    echo "✓ Successfully switched to PRODUCTION mode"
    echo "  - Log Level: ERROR"
    echo "  - Background Color: Red (#FF0000)"
else
    echo "✗ Not in production mode!"
    exit 1
fi

if echo "$RESPONSE" | grep -q "ERROR"; then
    echo "✓ Log level changed to ERROR"
else
    echo "✗ Log level not changed!"
    exit 1
fi

echo ""
echo "Step 5: Check init container logs for new pod"
echo "---------------------------------------"
kubectl logs $NEW_POD_NAME -c template-processor | tail -15

echo ""
echo "Step 6: Verify nginx log format changed"
echo "---------------------------------------"
# Generate some traffic
for i in {1..3}; do
    curl -s http://$MINIKUBE_IP:$NODE_PORT/ > /dev/null
done
sleep 1

echo "Recent access logs (should show PRODUCTION prefix):"
LOGS=$(kubectl exec $NEW_POD_NAME -- tail -3 /var/log/nginx/access.log)
echo "$LOGS"

if echo "$LOGS" | grep -q "PRODUCTION"; then
    echo "✓ Log format updated to PRODUCTION"
else
    echo "✗ Log format not updated!"
    exit 1
fi

echo ""
echo "Step 7: Switch back to Development"
echo "---------------------------------------"
kubectl delete configmap webapp-config
kubectl apply -f "$BASE_DIR/dev/configmap-dev.yaml"
kubectl rollout restart deployment/webapp
kubectl rollout status deployment/webapp --timeout=60s

sleep 3
RESPONSE=$(curl -s http://$MINIKUBE_IP:$NODE_PORT/)
if echo "$RESPONSE" | grep -q "DEVELOPMENT"; then
    echo "✓ Successfully switched back to DEVELOPMENT"
else
    echo "✗ Failed to switch back to development!"
    exit 1
fi

echo ""
echo "========================================="
echo "✓ Environment switching test passed!"
echo "========================================="
echo ""
echo "Key Observations:"
echo "1. ConfigMap changes require pod restart (no auto-reload)"
echo "2. Init container re-processes templates on each pod start"
echo "3. Same template files, different output based on environment"
echo "4. Both configuration and log format changed successfully"
