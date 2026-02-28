#!/bin/bash
# Test 1: 기본 Ambassador 패턴 - 로그 프록시

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

# Source utilities
source "$SCRIPT_DIR/test-utils.sh"

# Test configuration
POD_NAME="random-generator"
SERVICE_NAME="random-generator"
MAIN_CONTAINER="main"
AMBASSADOR_CONTAINER="ambassador"
NAMESPACE="default"

# Main test function
run_test() {
    print_header "TEST 1: Basic Ambassador Pattern - Log Proxy"

    print_info "Test Description:"
    echo "  - Verify Ambassador container proxies logs from main application"
    echo "  - Check localhost communication between containers"
    echo "  - Validate external access to main application"
    echo ""

    # Step 1: Cleanup existing resources
    print_info "Step 1: Cleanup existing resources"
    cleanup_resource "service" "$SERVICE_NAME"
    cleanup_pod "$POD_NAME"
    echo ""

    # Step 2: Apply manifest
    print_info "Step 2: Applying manifest..."
    if kubectl apply -f "$MANIFEST_DIR/test1-basic-log-proxy.yaml"; then
        print_success "Manifest applied successfully"
    else
        print_error "Failed to apply manifest"
        return 1
    fi
    echo ""

    # Step 3: Wait for pod to be running
    print_info "Step 3: Waiting for pod to be running..."
    if ! wait_for_pod_running "$POD_NAME" 90; then
        print_error "Pod did not start"
        kubectl describe pod $POD_NAME
        return 1
    fi
    echo ""

    # Step 4: Check both containers are running
    print_info "Step 4: Verifying both containers are running..."
    sleep 5

    if is_container_running "$POD_NAME" "$MAIN_CONTAINER"; then
        assert_success "true" "Main container is running"
    else
        assert_success "false" "Main container is running"
    fi

    if is_container_running "$POD_NAME" "$AMBASSADOR_CONTAINER"; then
        assert_success "true" "Ambassador container is running"
    else
        assert_success "false" "Ambassador container is running"
    fi
    echo ""

    # Step 5: Check main container logs for localhost communication
    print_info "Step 5: Checking main container logs for localhost usage..."
    sleep 5

    main_logs=$(get_pod_logs "$POD_NAME" "$MAIN_CONTAINER" "$NAMESPACE" 100)

    # The main container should be using localhost:9009 (LOG_URL)
    if echo "$main_logs" | grep -q "localhost"; then
        print_success "Main container is using localhost for communication"
    else
        print_warning "Cannot verify localhost usage in logs"
    fi
    echo ""

    # Step 6: Check ambassador container logs
    print_info "Step 6: Checking ambassador container logs..."
    sleep 3

    ambassador_logs=$(get_pod_logs "$POD_NAME" "$AMBASSADOR_CONTAINER" "$NAMESPACE" 50)

    if [ -n "$ambassador_logs" ]; then
        print_success "Ambassador container has logs"
        echo ""
        print_info "Sample ambassador logs:"
        echo "$ambassador_logs" | head -10
    else
        print_warning "Ambassador container has no logs yet"
    fi
    echo ""

    # Step 7: Test external access to main application
    print_info "Step 7: Testing external access to main application..."

    # Get service NodePort
    nodeport=$(kubectl get service $SERVICE_NAME -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
    minikube_ip=$(minikube ip 2>/dev/null)

    if [ -n "$nodeport" ] && [ -n "$minikube_ip" ]; then
        print_info "Service exposed at: http://$minikube_ip:$nodeport"

        # Try to access the service
        if curl -s --max-time 5 "http://$minikube_ip:$nodeport" > /dev/null; then
            print_success "External access to main application works"
        else
            print_warning "Could not access service externally (may be expected in some environments)"
        fi
    else
        print_warning "Could not determine service endpoint"
    fi
    echo ""

    # Step 8: Verify pod status
    print_info "Step 8: Final pod status check..."
    pod_status=$(kubectl get pod $POD_NAME -o jsonpath='{.status.phase}')
    assert_equals "$pod_status" "Running" "Pod is in Running state"
    echo ""

    # Step 9: Display resource usage
    print_info "Step 9: Resource usage:"
    kubectl top pod $POD_NAME --containers 2>/dev/null || print_warning "Metrics not available (metrics-server may not be installed)"
    echo ""

    print_test_summary
    local result=$?

    # Cleanup (optional, comment out to keep resources for inspection)
    # print_info "Cleaning up resources..."
    # cleanup_pod "$POD_NAME"
    # cleanup_resource "service" "$SERVICE_NAME"

    return $result
}

# Run the test
run_test
exit $?
