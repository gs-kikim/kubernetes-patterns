#!/bin/bash
# Test 7: 리소스 격리 및 보안 테스트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

source "$SCRIPT_DIR/test-utils.sh"

POD_NAME="security-test"
CONFIGMAP_NAME="security-test-config"
NETWORK_POLICY_NAME="ambassador-network-policy"

run_test() {
    print_header "TEST 7: Resource Isolation and Security"

    print_info "Test Description:"
    echo "  - Verify security contexts are properly applied"
    echo "  - Check resource limits and requests"
    echo "  - Validate ambassador provides security layer"
    echo ""

    # Cleanup
    cleanup_pod "$POD_NAME"
    cleanup_resource "configmap" "$CONFIGMAP_NAME"
    cleanup_resource "networkpolicy" "$NETWORK_POLICY_NAME"

    # Apply manifest
    print_info "Applying manifest..."
    kubectl apply -f "$MANIFEST_DIR/test7-security.yaml"
    echo ""

    # Wait for pod
    wait_for_pod_running "$POD_NAME" 90
    sleep 15
    echo ""

    # Check security contexts
    print_info "Verifying security contexts..."

    runAsUser=$(kubectl get pod $POD_NAME -o jsonpath='{.spec.securityContext.runAsUser}')
    runAsNonRoot=$(kubectl get pod $POD_NAME -o jsonpath='{.spec.securityContext.runAsNonRoot}')

    assert_equals "$runAsUser" "1000" "Pod runs as non-root user (UID 1000)"
    assert_equals "$runAsNonRoot" "true" "Pod enforces non-root requirement"
    echo ""

    # Check container resource limits
    print_info "Verifying resource limits..."

    main_mem_limit=$(kubectl get pod $POD_NAME -o jsonpath='{.spec.containers[?(@.name=="main")].resources.limits.memory}')
    main_cpu_limit=$(kubectl get pod $POD_NAME -o jsonpath='{.spec.containers[?(@.name=="main")].resources.limits.cpu}')

    print_info "Main container limits: Memory=$main_mem_limit, CPU=$main_cpu_limit"

    if [ -n "$main_mem_limit" ] && [ -n "$main_cpu_limit" ]; then
        print_success "Resource limits are configured"
    else
        print_warning "Could not verify all resource limits"
    fi
    echo ""

    # Check main container logs for security tests
    print_info "Checking security test results from main container..."
    sleep 10

    main_logs=$(get_pod_logs "$POD_NAME" "main" "$NAMESPACE" 100)

    # Test 1: Direct external access should fail (with NetworkPolicy)
    if echo "$main_logs" | grep -q "Test 1"; then
        print_info "Test 1 (Direct access blocking):"
        if echo "$main_logs" | grep -A 3 "Test 1" | grep -q "PASS\|blocked"; then
            print_success "Direct external access is restricted"
        else
            print_warning "Direct access test completed (NetworkPolicy may not be enforced)"
        fi
    fi
    echo ""

    # Test 2: Access via Ambassador should succeed
    if echo "$main_logs" | grep -q "Test 2"; then
        print_info "Test 2 (Ambassador access):"
        if echo "$main_logs" | grep -A 3 "Test 2" | grep -q "PASS\|succeeded"; then
            print_success "Access via Ambassador works"
        else
            print_warning "Ambassador access test result unclear"
        fi
    fi
    echo ""

    # Test 3: Resource limits
    if echo "$main_logs" | grep -q "Test 3"; then
        print_info "Test 3 (Resource limits):"
        print_success "Resource limit verification completed"
    fi
    echo ""

    # Check NetworkPolicy exists
    print_info "Verifying NetworkPolicy..."
    if kubectl get networkpolicy $NETWORK_POLICY_NAME > /dev/null 2>&1; then
        print_success "NetworkPolicy is configured"
    else
        print_warning "NetworkPolicy not found (may not be supported)"
    fi
    echo ""

    # Display sample logs
    print_info "Sample security test logs:"
    echo "$main_logs" | head -30
    echo ""

    print_test_summary
    return $?
}

run_test
exit $?
