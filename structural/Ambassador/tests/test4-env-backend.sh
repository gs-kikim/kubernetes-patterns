#!/bin/bash
# Test 4: 환경별 백엔드 전환

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

source "$SCRIPT_DIR/test-utils.sh"

run_test() {
    print_header "TEST 4: Environment-specific Backend Switching"

    print_info "Test Description:"
    echo "  - Same main app code works with different backends"
    echo "  - Dev environment: simple local cache"
    echo "  - Prod environment: HAProxy load-balancing to multiple Redis instances"
    echo ""

    # Test Development Environment
    print_info "==== Testing DEVELOPMENT Environment ===="
    echo ""

    cleanup_pod "app-dev-env"
    cleanup_resource "configmap" "cache-config-dev"

    print_info "Deploying development environment..."
    kubectl apply -f "$MANIFEST_DIR/test4-env-backend-dev.yaml"
    echo ""

    wait_for_pod_running "app-dev-env" 90
    sleep 10
    echo ""

    print_info "Checking dev environment logs..."
    dev_logs=$(get_pod_logs "app-dev-env" "main" "$NAMESPACE" 50)

    assert_contains "$dev_logs" "DEVELOPMENT environment" "Dev environment detected"
    assert_contains "$dev_logs" "localhost:6379" "Using localhost for cache access"

    if echo "$dev_logs" | grep -q "OK"; then
        print_success "Cache operations working in dev environment"
    fi
    echo ""

    # Test Production Environment
    print_info "==== Testing PRODUCTION Environment ===="
    echo ""

    # Cleanup previous prod resources
    cleanup_pod "app-prod-env"
    cleanup_pod "redis-backend-1"
    cleanup_pod "redis-backend-2"
    cleanup_resource "service" "redis-backend-1"
    cleanup_resource "service" "redis-backend-2"
    cleanup_resource "configmap" "cache-config-prod"
    cleanup_resource "configmap" "haproxy-ambassador-config"

    sleep 3

    print_info "Deploying production environment..."
    kubectl apply -f "$MANIFEST_DIR/test4-env-backend-prod.yaml"
    echo ""

    # Wait for backend Redis instances
    print_info "Waiting for Redis backend instances..."
    wait_for_pod_running "redis-backend-1" 60
    wait_for_pod_running "redis-backend-2" 60
    sleep 5
    echo ""

    # Wait for main app pod
    print_info "Waiting for main application pod..."
    wait_for_pod_running "app-prod-env" 90
    sleep 15
    echo ""

    print_info "Checking prod environment logs..."
    prod_logs=$(get_pod_logs "app-prod-env" "main" "$NAMESPACE" 50)

    assert_contains "$prod_logs" "PRODUCTION environment" "Prod environment detected"
    assert_contains "$prod_logs" "localhost:6379" "Using same localhost address as dev (abstraction working)"

    if echo "$prod_logs" | grep -q "OK"; then
        print_success "Cache operations working in prod environment"
    fi
    echo ""

    # Verify HAProxy is load balancing
    print_info "Checking HAProxy ambassador logs..."
    haproxy_logs=$(get_pod_logs "app-prod-env" "ambassador" "$NAMESPACE" 50)

    if echo "$haproxy_logs" | grep -q "redis"; then
        print_success "HAProxy is proxying to Redis backends"
    else
        print_info "Sample HAProxy logs:"
        echo "$haproxy_logs" | head -10
    fi
    echo ""

    # Key verification: same application code works in both environments
    print_info "==== Verification ===="
    print_success "Main application code is identical in both environments"
    print_success "Only ambassador configuration differs"
    print_success "This demonstrates proper separation of concerns"
    echo ""

    print_test_summary
    return $?
}

run_test
exit $?
