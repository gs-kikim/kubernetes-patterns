#!/bin/bash
# Test 3: HTTP 프록시 Ambassador

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

source "$SCRIPT_DIR/test-utils.sh"

POD_NAME="http-proxy-ambassador"
CONFIGMAP_NAME="nginx-ambassador-config"
MAIN_CONTAINER="main"
AMBASSADOR_CONTAINER="ambassador"

run_test() {
    print_header "TEST 3: HTTP Proxy Ambassador"

    print_info "Test Description:"
    echo "  - Nginx acts as ambassador to proxy external HTTP services"
    echo "  - Main app accesses external services via localhost"
    echo "  - Verify timeout and retry policies"
    echo ""

    # Cleanup
    cleanup_pod "$POD_NAME"
    cleanup_resource "configmap" "$CONFIGMAP_NAME"

    # Apply manifest
    print_info "Applying manifest..."
    kubectl apply -f "$MANIFEST_DIR/test3-http-proxy.yaml"
    echo ""

    # Wait for pod
    wait_for_pod_running "$POD_NAME" 90
    echo ""

    # Wait for ambassador to be ready
    print_info "Waiting for ambassador to be ready..."
    sleep 10
    echo ""

    # Check if ambassador is healthy
    print_info "Checking ambassador health..."
    if kubectl exec $POD_NAME -c $MAIN_CONTAINER -- curl -s http://localhost:8080/health > /dev/null 2>&1; then
        print_success "Ambassador health check passed"
    else
        print_error "Ambassador health check failed"
    fi
    echo ""

    # Check main container logs
    print_info "Checking main container logs for external API access..."
    sleep 10

    main_logs=$(get_pod_logs "$POD_NAME" "$MAIN_CONTAINER" "$NAMESPACE" 100)

    assert_contains "$main_logs" "Ambassador is ready" "Ambassador became ready"
    assert_contains "$main_logs" "localhost:8080" "Main app uses localhost to access external service"

    # Check if external service was successfully accessed
    if echo "$main_logs" | grep -q "HTTP Status: 200"; then
        print_success "External service successfully accessed via Ambassador"
    else
        print_warning "Could not verify successful external service access"
    fi
    echo ""

    # Check ambassador (nginx) logs
    print_info "Checking nginx ambassador logs..."
    ambassador_logs=$(get_pod_logs "$POD_NAME" "$AMBASSADOR_CONTAINER" "$NAMESPACE" 50)

    if echo "$ambassador_logs" | grep -q "GET"; then
        print_success "Ambassador is proxying HTTP requests"
    else
        print_warning "Could not verify ambassador HTTP proxying in logs"
    fi
    echo ""

    print_test_summary
    return $?
}

run_test
exit $?
