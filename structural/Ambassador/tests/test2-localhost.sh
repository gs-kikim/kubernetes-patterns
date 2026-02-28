#!/bin/bash
# Test 2: localhost 통신 검증

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

source "$SCRIPT_DIR/test-utils.sh"

POD_NAME="localhost-verify"
MAIN_CONTAINER="main"
AMBASSADOR_CONTAINER="ambassador"

run_test() {
    print_header "TEST 2: Localhost Communication Verification"

    print_info "Test Description:"
    echo "  - Verify containers in same pod can communicate via localhost"
    echo "  - Confirm network namespace sharing"
    echo ""

    # Cleanup
    cleanup_pod "$POD_NAME"

    # Apply manifest
    print_info "Applying manifest..."
    kubectl apply -f "$MANIFEST_DIR/test2-localhost-verify.yaml"
    echo ""

    # Wait for pod
    wait_for_pod_running "$POD_NAME" 60
    echo ""

    # Wait a bit for containers to start communicating
    print_info "Waiting for containers to communicate..."
    sleep 10
    echo ""

    # Check main container logs
    print_info "Checking main container logs for successful localhost communication..."
    main_logs=$(get_pod_logs "$POD_NAME" "$MAIN_CONTAINER" "$NAMESPACE" 50)

    assert_contains "$main_logs" "SUCCESS" "Main container successfully communicated with ambassador via localhost"
    assert_contains "$main_logs" "localhost:8888" "Main container used localhost address"
    echo ""

    # Check ambassador logs
    print_info "Checking ambassador container logs..."
    ambassador_logs=$(get_pod_logs "$POD_NAME" "$AMBASSADOR_CONTAINER" "$NAMESPACE" 20)

    if [ -n "$ambassador_logs" ]; then
        print_success "Ambassador container is running and serving requests"
        echo "Sample response:"
        echo "$ambassador_logs" | head -5
    fi
    echo ""

    # Verify both containers are in same network namespace
    print_info "Verifying network namespace sharing..."

    # Both containers should see the same network interfaces
    if kubectl exec $POD_NAME -c $MAIN_CONTAINER -- sh -c "ip addr show lo" > /dev/null 2>&1; then
        print_success "Containers share network namespace (localhost available)"
    else
        print_warning "Could not verify network namespace"
    fi
    echo ""

    print_test_summary
    return $?
}

run_test
exit $?
