#!/bin/bash

# Common utility functions for Immutable Configuration tests

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test result counters
TESTS_PASSED=0
TESTS_FAILED=0

# Print colored message
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Check if minikube is running
check_minikube() {
    print_info "Checking minikube status..."
    if ! minikube status &> /dev/null; then
        print_error "Minikube is not running. Please start minikube first."
        exit 1
    fi
    print_success "Minikube is running"
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
}

# Wait for pod to be ready
wait_for_pod() {
    local pod_name=$1
    local timeout=${2:-60}

    print_info "Waiting for pod '$pod_name' to be ready (timeout: ${timeout}s)..."

    if kubectl wait --for=condition=Ready pod/$pod_name --timeout=${timeout}s 2>/dev/null; then
        print_success "Pod '$pod_name' is ready"
        return 0
    else
        print_warning "Pod '$pod_name' did not become ready within ${timeout}s"
        return 1
    fi
}

# Wait for deployment to be ready
wait_for_deployment() {
    local deployment_name=$1
    local timeout=${2:-60}

    print_info "Waiting for deployment '$deployment_name' to be ready (timeout: ${timeout}s)..."

    if kubectl wait --for=condition=Available deployment/$deployment_name --timeout=${timeout}s 2>/dev/null; then
        print_success "Deployment '$deployment_name' is ready"
        return 0
    else
        print_error "Deployment '$deployment_name' did not become ready within ${timeout}s"
        return 1
    fi
}

# Get pod status
get_pod_status() {
    local pod_name=$1
    kubectl get pod $pod_name -o jsonpath='{.status.phase}' 2>/dev/null
}

# Get pod logs
get_pod_logs() {
    local pod_name=$1
    local container=${2:-}

    if [ -n "$container" ]; then
        kubectl logs $pod_name -c $container 2>/dev/null
    else
        kubectl logs $pod_name 2>/dev/null
    fi
}

# Get init container logs
get_init_logs() {
    local pod_name=$1
    local init_container=${2:-config-init}

    kubectl logs $pod_name -c $init_container 2>/dev/null
}

# Delete resource if exists
delete_if_exists() {
    local resource_type=$1
    local resource_name=$2

    if kubectl get $resource_type $resource_name &> /dev/null; then
        print_info "Deleting existing $resource_type '$resource_name'..."
        kubectl delete $resource_type $resource_name --grace-period=0 --force &> /dev/null
        sleep 2
    fi
}

# Cleanup resources
cleanup() {
    local resource_type=$1
    local resource_name=$2

    print_info "Cleaning up $resource_type '$resource_name'..."
    kubectl delete $resource_type $resource_name --ignore-not-found=true --grace-period=0 --force &> /dev/null
    sleep 2
}

# Assert pod status
assert_pod_status() {
    local pod_name=$1
    local expected_status=$2

    local actual_status=$(get_pod_status $pod_name)

    if [ "$actual_status" == "$expected_status" ]; then
        print_success "Pod status is '$expected_status' as expected"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "Expected pod status '$expected_status', but got '$actual_status'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Assert string contains
assert_contains() {
    local haystack=$1
    local needle=$2
    local message=${3:-"String contains expected value"}

    if echo "$haystack" | grep -q "$needle"; then
        print_success "$message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "$message - Expected to find '$needle' but it was not present"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Print test summary
print_test_summary() {
    echo ""
    print_header "Test Summary"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo -e "Total: $((TESTS_PASSED + TESTS_FAILED))"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        print_success "All tests passed! ✓"
        return 0
    else
        print_error "Some tests failed! ✗"
        return 1
    fi
}

# Build config image for minikube
build_config_image() {
    local env=$1
    local version=${2:-1.0}

    print_header "Building Config Image for $env Environment"

    cd $(dirname $0)/..

    # Use minikube's Docker daemon
    print_info "Setting Docker environment to minikube..."
    eval $(minikube docker-env)

    # Build the image
    print_info "Building image k8spatterns/immutable-config-$env:$version..."
    docker build -t k8spatterns/immutable-config-$env:$version \
        --build-arg ENV=$env \
        -f Dockerfile.config . 2>&1 | grep -v "WARNING"

    if [ $? -eq 0 ]; then
        print_success "Image built successfully"

        # Verify image exists
        if docker images | grep -q "k8spatterns/immutable-config-$env.*$version"; then
            print_success "Image verified in minikube's Docker"
        else
            print_error "Image not found in minikube's Docker"
            return 1
        fi
    else
        print_error "Failed to build image"
        return 1
    fi
}

# Measure pod startup time
measure_startup_time() {
    local pod_name=$1

    print_info "Measuring startup time for pod '$pod_name'..."

    local start_time=$(date +%s%N)

    if wait_for_pod $pod_name 120; then
        local end_time=$(date +%s%N)
        local duration_ms=$(( (end_time - start_time) / 1000000 ))
        print_success "Pod started in ${duration_ms}ms"
        echo $duration_ms
        return 0
    else
        print_error "Pod failed to start"
        return 1
    fi
}
