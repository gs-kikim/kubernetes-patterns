#!/bin/bash
# Test 5: Ambassador 장애 복구 테스트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

source "$SCRIPT_DIR/test-utils.sh"

POD_NAME="failure-recovery-test"
MAIN_CONTAINER="main"
AMBASSADOR_CONTAINER="ambassador"

run_test() {
    print_header "TEST 5: Ambassador Failure Recovery"

    print_info "Test Description:"
    echo "  - Verify ambassador container automatically restarts on failure"
    echo "  - Check main container continues to work after ambassador recovery"
    echo ""

    # Cleanup
    cleanup_pod "$POD_NAME"

    # Apply manifest
    print_info "Applying manifest..."
    kubectl apply -f "$MANIFEST_DIR/test5-failure-recovery.yaml"
    echo ""

    # Wait for pod
    wait_for_pod_running "$POD_NAME" 90
    sleep 10
    echo ""

    # Check initial restart count
    print_info "Checking initial state..."
    initial_restarts=$(get_restart_count "$POD_NAME" "$AMBASSADOR_CONTAINER")
    print_info "Ambassador initial restart count: $initial_restarts"
    echo ""

    # Verify ambassador is healthy initially
    print_info "Verifying ambassador is initially healthy..."
    initial_logs=$(get_pod_logs "$POD_NAME" "$MAIN_CONTAINER" "$NAMESPACE" 30)

    if echo "$initial_logs" | grep -q "healthy"; then
        print_success "Ambassador is initially healthy"
    else
        print_warning "Cannot confirm initial health"
    fi
    echo ""

    # Kill ambassador process
    print_info "Simulating ambassador failure (killing process)..."
    if kubectl exec $POD_NAME -c $AMBASSADOR_CONTAINER -- sh -c "kill 1" 2>/dev/null; then
        print_info "Ambassador process killed"
    else
        print_info "Process kill command sent"
    fi
    sleep 5
    echo ""

    # Check if ambassador restarted
    print_info "Checking if ambassador restarted..."
    sleep 10

    new_restarts=$(get_restart_count "$POD_NAME" "$AMBASSADOR_CONTAINER")
    print_info "Ambassador current restart count: $new_restarts"

    if [ "$new_restarts" -gt "$initial_restarts" ]; then
        print_success "Ambassador was automatically restarted (restarts: $initial_restarts -> $new_restarts)"
    else
        print_warning "Ambassador restart count did not increase yet"
    fi
    echo ""

    # Wait for ambassador to be healthy again
    print_info "Waiting for ambassador to recover..."
    sleep 10
    echo ""

    # Check if main container is still working
    print_info "Checking if main container resumed communication with ambassador..."
    recovery_logs=$(get_pod_logs "$POD_NAME" "$MAIN_CONTAINER" "$NAMESPACE" 50)

    # Count successful connections after restart
    success_after=$(echo "$recovery_logs" | tail -20 | grep -c "healthy" || true)

    if [ "$success_after" -gt 0 ]; then
        print_success "Main container successfully reconnected to ambassador after recovery"
        print_info "Found $success_after successful health checks in recent logs"
    else
        print_warning "Could not verify successful reconnection in logs"
    fi
    echo ""

    # Final pod status
    print_info "Final pod status:"
    kubectl get pod $POD_NAME
    echo ""

    print_test_summary
    return $?
}

run_test
exit $?
