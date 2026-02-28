#!/bin/bash

# Test 1: Basic Init Container Configuration Test
# This test verifies that the basic init container pattern works correctly

set -e

SCRIPT_DIR=$(dirname "$0")
source "$SCRIPT_DIR/common.sh"

print_header "Test 1: Basic Init Container Configuration"

# Prerequisites check
check_kubectl
check_minikube

# Build config image
build_config_image "dev" "1.0"

# Cleanup any existing resources
cleanup "deployment" "immutable-config-app"

# Deploy the application
print_info "Deploying application with immutable configuration..."
kubectl apply -f $SCRIPT_DIR/../manifests/01-basic-deployment.yaml

# Wait for deployment to be ready
if ! wait_for_deployment "immutable-config-app" 120; then
    print_error "Deployment failed to become ready"
    kubectl describe deployment immutable-config-app
    kubectl get pods -l app=immutable-config-demo
    exit 1
fi

# Get the pod name
POD_NAME=$(kubectl get pods -l app=immutable-config-demo -o jsonpath='{.items[0].metadata.name}')
print_info "Pod name: $POD_NAME"

# Check init container logs
print_info "Checking init container logs..."
INIT_LOGS=$(get_init_logs $POD_NAME)
echo "$INIT_LOGS"

# Check application container logs
print_info "Checking application container logs..."
APP_LOGS=$(get_pod_logs $POD_NAME app)
echo "$APP_LOGS"

# Verify configuration was loaded
print_header "Verification Tests"

assert_contains "$APP_LOGS" "app.properties" "Configuration file exists"
assert_contains "$APP_LOGS" "app.environment=development" "Development environment configured"
assert_contains "$APP_LOGS" "database.host=dev-db.local" "Database host configured"
assert_contains "$APP_LOGS" "log.level=DEBUG" "Log level configured"

# Check if database.yaml exists (multi-file test)
if echo "$APP_LOGS" | grep -q "database.yaml"; then
    assert_contains "$APP_LOGS" "host: dev-db.local" "Database YAML configured"
fi

# Verify pod is running
assert_pod_status $POD_NAME "Running"

# Display pod details
print_info "Pod details:"
kubectl describe pod $POD_NAME | grep -A 5 "Init Containers:"
kubectl describe pod $POD_NAME | grep -A 10 "Containers:"

# Test configuration file permissions
print_info "Checking file permissions in pod..."
kubectl exec $POD_NAME -- ls -la /app/config/

# Cleanup
print_info "Cleaning up resources..."
cleanup "deployment" "immutable-config-app"

# Print test summary
print_test_summary
