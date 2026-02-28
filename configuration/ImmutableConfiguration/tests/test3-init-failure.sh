#!/bin/bash

# Test 3: Init Container Failure Scenario Test
# This test verifies that the application container does not start when init container fails

set -e

SCRIPT_DIR=$(dirname "$0")
source "$SCRIPT_DIR/common.sh"

print_header "Test 3: Init Container Failure Scenario"

# Prerequisites check
check_kubectl
check_minikube

# Cleanup any existing resources
cleanup "pod" "init-failure-test"

# Deploy the pod with failing init container
print_info "Deploying pod with intentionally failing init container..."
kubectl apply -f $SCRIPT_DIR/../manifests/02-init-failure-test.yaml

# Wait a bit for the pod to attempt initialization
sleep 10

# Get pod status
POD_STATUS=$(get_pod_status init-failure-test)
print_info "Current pod status: $POD_STATUS"

# Verify pod is NOT in Running state
print_header "Verification Tests"

if [ "$POD_STATUS" == "Running" ]; then
    print_error "Pod should NOT be running when init container fails"
    TESTS_FAILED=$((TESTS_FAILED + 1))
else
    print_success "Pod is not running (status: $POD_STATUS) - as expected"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# Check pod phase and conditions
print_info "Pod phase details:"
kubectl get pod init-failure-test -o jsonpath='{.status.phase}'
echo ""

print_info "Pod conditions:"
kubectl get pod init-failure-test -o jsonpath='{.status.conditions[*].type}'
echo ""

# Get init container status
print_info "Init container state:"
kubectl get pod init-failure-test -o jsonpath='{.status.initContainerStatuses[0].state}'
echo ""

# Check init container logs
print_info "Init container logs:"
INIT_LOGS=$(kubectl logs init-failure-test -c failing-init 2>&1 || true)
echo "$INIT_LOGS"

assert_contains "$INIT_LOGS" "intentionally failing" "Init container logged failure message"

# Verify the main container has not started
print_info "Main container state:"
MAIN_CONTAINER_STARTED=$(kubectl get pod init-failure-test -o jsonpath='{.status.containerStatuses[0].started}' 2>/dev/null || echo "false")

if [ "$MAIN_CONTAINER_STARTED" == "false" ] || [ -z "$MAIN_CONTAINER_STARTED" ]; then
    print_success "Main container has not started - as expected (started: $MAIN_CONTAINER_STARTED)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_error "Main container should not have started"
    echo "Started status: $MAIN_CONTAINER_STARTED"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Check pod events
print_info "Recent pod events:"
kubectl describe pod init-failure-test | grep -A 10 "Events:"

# Verify restart attempts
print_info "Checking for init container restarts..."
sleep 15  # Wait for potential restarts

RESTART_COUNT=$(kubectl get pod init-failure-test -o jsonpath='{.status.initContainerStatuses[0].restartCount}')
print_info "Init container restart count: $RESTART_COUNT"

if [ "$RESTART_COUNT" -gt 0 ]; then
    print_success "Init container is being restarted (attempt to recover) - count: $RESTART_COUNT"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_warning "No restarts observed yet (may need more time)"
fi

# Cleanup
print_info "Cleaning up resources..."
cleanup "pod" "init-failure-test"

# Print test summary
print_test_summary
