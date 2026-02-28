#!/bin/bash
# Test 6: Native Sidecar 시작 순서 검증

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

source "$SCRIPT_DIR/test-utils.sh"

POD_NAME="native-sidecar-test"

run_test() {
    print_header "TEST 6: Native Sidecar Startup Order"

    print_info "Test Description:"
    echo "  - Verify Native Sidecar (restartPolicy: Always) starts before main container"
    echo "  - Check startupProbe ensures ambassador is ready before main starts"
    echo "  - Requires Kubernetes 1.28+"
    echo ""

    # Check Kubernetes version
    print_info "Checking Kubernetes version..."
    k8s_version=$(kubectl version --short 2>/dev/null | grep Server || kubectl version -o json | grep gitVersion)
    print_info "Kubernetes version: $k8s_version"
    echo ""

    # Cleanup
    cleanup_pod "$POD_NAME"
    cleanup_resource "configmap" "startup-logger-config"

    # Apply manifest
    print_info "Applying manifest..."
    if kubectl apply -f "$MANIFEST_DIR/test6-native-sidecar.yaml"; then
        print_success "Manifest applied"
    else
        print_error "Failed to apply manifest (Native Sidecar may not be supported)"
        print_warning "Native Sidecar requires Kubernetes 1.28+"
        return 1
    fi
    echo ""

    # Wait for pod
    print_info "Waiting for pod to be running..."
    if ! wait_for_pod_running "$POD_NAME" 90; then
        print_error "Pod failed to start"
        kubectl describe pod $POD_NAME
        return 1
    fi
    sleep 10
    echo ""

    # Check init container logs
    print_info "Checking init container logs..."
    init_logs=$(kubectl logs $POD_NAME -c init-setup 2>/dev/null || echo "")

    if [ -n "$init_logs" ]; then
        print_success "Init container ran successfully"
        echo "Init logs:"
        echo "$init_logs"
    fi
    echo ""

    # Check native sidecar logs
    print_info "Checking Native Sidecar ambassador logs..."
    sidecar_logs=$(kubectl logs $POD_NAME -c ambassador-sidecar 2>/dev/null || echo "")

    if [ -n "$sidecar_logs" ]; then
        print_success "Native Sidecar is running"
    fi
    echo ""

    # Check main container logs
    print_info "Checking main container logs for startup order verification..."
    main_logs=$(get_pod_logs "$POD_NAME" "main-app" "$NAMESPACE" 100)

    # Main container should report that ambassador was already ready
    assert_contains "$main_logs" "SUCCESS" "Main container found ambassador ready immediately"
    assert_contains "$main_logs" "Ambassador was ready before main started" "Startup order verified"

    echo ""
    print_info "Sample main container logs:"
    echo "$main_logs" | head -20
    echo ""

    # Verify container statuses
    print_info "Verifying container statuses..."
    kubectl get pod $POD_NAME -o jsonpath='{range .status.initContainerStatuses[*]}{.name}{"\t"}{.state}{"\n"}{end}' | while read line; do
        echo "  $line"
    done
    echo ""

    print_test_summary
    return $?
}

run_test
exit $?
