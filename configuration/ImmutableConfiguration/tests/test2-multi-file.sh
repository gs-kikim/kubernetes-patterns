#!/bin/bash

# Test 2: Multi-File Configuration Management Test
# This test verifies handling multiple configuration files

set -e

SCRIPT_DIR=$(dirname "$0")
source "$SCRIPT_DIR/common.sh"

print_header "Test 2: Multi-File Configuration Management"

# Prerequisites check
check_kubectl
check_minikube

# Build config image (should already exist from test1, but rebuild to be safe)
build_config_image "dev" "1.0"

# Cleanup any existing resources
cleanup "deployment" "multi-file-config-app"

# Deploy the application
print_info "Deploying application with multiple configuration files..."
kubectl apply -f $SCRIPT_DIR/../manifests/05-multi-file-deployment.yaml

# Wait for deployment to be ready
if ! wait_for_deployment "multi-file-config-app" 120; then
    print_error "Deployment failed to become ready"
    exit 1
fi

# Get the pod name
POD_NAME=$(kubectl get pods -l app=multi-file-demo -o jsonpath='{.items[0].metadata.name}')
print_info "Pod name: $POD_NAME"

# Wait for pod to be ready
wait_for_pod $POD_NAME 60

# Check application logs
print_info "Checking application logs..."
APP_LOGS=$(get_pod_logs $POD_NAME app)
echo "$APP_LOGS"

# Verify all configuration files are present
print_header "Verification Tests"

assert_contains "$APP_LOGS" "app.properties" "app.properties file found"
assert_contains "$APP_LOGS" "database.yaml" "database.yaml file found"

# Verify app.properties content
assert_contains "$APP_LOGS" "app.environment=development" "app.properties environment setting"
assert_contains "$APP_LOGS" "database.host=dev-db.local" "app.properties database host"
assert_contains "$APP_LOGS" "cache.host=dev-redis.local" "app.properties cache host"

# Verify database.yaml content
assert_contains "$APP_LOGS" "host: dev-db.local" "database.yaml host"
assert_contains "$APP_LOGS" "pool:" "database.yaml pool configuration"
assert_contains "$APP_LOGS" "min: 2" "database.yaml min pool size"
assert_contains "$APP_LOGS" "max: 10" "database.yaml max pool size"

# List all files in config directory
print_info "All configuration files in pod:"
kubectl exec $POD_NAME -- find /app/config -type f

# Count configuration files
FILE_COUNT=$(kubectl exec $POD_NAME -- find /app/config -type f | wc -l)
print_info "Total configuration files: $FILE_COUNT"

if [ $FILE_COUNT -ge 2 ]; then
    print_success "Multiple configuration files loaded successfully"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_error "Expected at least 2 configuration files, found $FILE_COUNT"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Cleanup
print_info "Cleaning up resources..."
cleanup "deployment" "multi-file-config-app"

# Print test summary
print_test_summary
