#!/bin/bash

# Test 4: Immutable ConfigMap vs Init Container Comparison Test
# This test compares startup time and resource usage between ConfigMap and Init Container approaches

set -e

SCRIPT_DIR=$(dirname "$0")
source "$SCRIPT_DIR/common.sh"

print_header "Test 4: ConfigMap vs Init Container Comparison"

# Prerequisites check
check_kubectl
check_minikube

# Build config image for init container approach
build_config_image "dev" "1.0"

# Cleanup any existing resources
cleanup "pod" "configmap-comparison"
cleanup "deployment" "immutable-config-app"
cleanup "configmap" "app-config-immutable"

# Test 1: ConfigMap Approach
print_header "Testing ConfigMap Approach"

print_info "Creating immutable ConfigMap and deploying pod..."
kubectl apply -f $SCRIPT_DIR/../manifests/04-configmap-comparison.yaml

# Measure startup time for ConfigMap approach
CONFIGMAP_START=$(date +%s%N)
if wait_for_pod "configmap-comparison" 60; then
    CONFIGMAP_END=$(date +%s%N)
    CONFIGMAP_DURATION=$(( (CONFIGMAP_END - CONFIGMAP_START) / 1000000 ))
    print_success "ConfigMap pod started in ${CONFIGMAP_DURATION}ms"
else
    print_error "ConfigMap pod failed to start"
    exit 1
fi

# Check ConfigMap pod logs
print_info "ConfigMap pod logs:"
CONFIGMAP_LOGS=$(get_pod_logs "configmap-comparison")
echo "$CONFIGMAP_LOGS"

assert_contains "$CONFIGMAP_LOGS" "app.name=MyApp" "ConfigMap configuration loaded"

# Get ConfigMap pod resource usage
print_info "ConfigMap pod resource usage:"
kubectl top pod configmap-comparison 2>/dev/null || print_warning "Metrics server may not be available"

# Cleanup ConfigMap test
cleanup "pod" "configmap-comparison"
sleep 5

# Test 2: Init Container Approach
print_header "Testing Init Container Approach"

print_info "Deploying pod with init container..."
kubectl apply -f $SCRIPT_DIR/../manifests/01-basic-deployment.yaml

# Wait for deployment to be ready and get pod name
sleep 5
POD_NAME=$(kubectl get pods -l app=immutable-config-demo -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$POD_NAME" ]; then
    print_error "Failed to get pod name"
    exit 1
fi

# Measure startup time for Init Container approach
INIT_START=$(date +%s%N)
if wait_for_pod "$POD_NAME" 120; then
    INIT_END=$(date +%s%N)
    INIT_DURATION=$(( (INIT_END - INIT_START) / 1000000 ))
    print_success "Init Container pod started in ${INIT_DURATION}ms"
else
    print_error "Init Container pod failed to start"
    exit 1
fi

# Check Init Container pod logs
print_info "Init Container pod logs:"
INIT_LOGS=$(get_pod_logs "$POD_NAME")
echo "$INIT_LOGS"

assert_contains "$INIT_LOGS" "app.properties" "Init Container configuration loaded"

# Get Init Container pod resource usage
print_info "Init Container pod resource usage:"
kubectl top pod $POD_NAME 2>/dev/null || print_warning "Metrics server may not be available"

# Compare Results
print_header "Comparison Results"

echo ""
echo "ConfigMap Approach:"
echo "  - Startup time: ${CONFIGMAP_DURATION}ms"
echo "  - Complexity: Low"
echo "  - Size limit: 1MB"
echo "  - File structure: Flat key-value"
echo ""

echo "Init Container Approach:"
echo "  - Startup time: ${INIT_DURATION}ms"
echo "  - Complexity: Medium (requires init container + volume)"
echo "  - Size limit: No limit (depends on container image)"
echo "  - File structure: Full directory structure"
echo ""

# Calculate overhead
OVERHEAD=$(( INIT_DURATION - CONFIGMAP_DURATION ))
OVERHEAD_PERCENT=$(( (OVERHEAD * 100) / CONFIGMAP_DURATION ))

echo "Init Container Overhead: ${OVERHEAD}ms (${OVERHEAD_PERCENT}%)"
echo ""

if [ $OVERHEAD_PERCENT -lt 50 ]; then
    print_success "Init Container overhead is acceptable (<50%)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_warning "Init Container has significant overhead (>${OVERHEAD_PERCENT}%)"
    print_info "This is expected due to image pull and copy operations"
fi

# Test ConfigMap immutability
print_header "Testing ConfigMap Immutability"

print_info "Attempting to modify immutable ConfigMap..."
if kubectl patch configmap app-config-immutable -p '{"data":{"app.properties":"modified"}}' 2>&1 | grep -q "field is immutable"; then
    print_success "ConfigMap is properly immutable"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_error "ConfigMap should be immutable"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Cleanup
print_info "Cleaning up resources..."
cleanup "deployment" "immutable-config-app"
cleanup "configmap" "app-config-immutable"

# Print test summary
print_test_summary
