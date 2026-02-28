#!/bin/bash
# Test utility functions for Ambassador pattern tests

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test result tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Print colored message
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} $1"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Wait for pod to be ready
wait_for_pod() {
    local pod_name=$1
    local timeout=${2:-60}
    local namespace=${3:-default}

    print_info "Waiting for pod '$pod_name' to be ready (timeout: ${timeout}s)..."

    if kubectl wait --for=condition=Ready pod/$pod_name \
        --timeout=${timeout}s \
        --namespace=$namespace > /dev/null 2>&1; then
        print_success "Pod '$pod_name' is ready"
        return 0
    else
        print_error "Pod '$pod_name' failed to become ready within ${timeout}s"
        kubectl get pod $pod_name --namespace=$namespace
        kubectl describe pod $pod_name --namespace=$namespace | tail -20
        return 1
    fi
}

# Wait for pod to be running (not necessarily ready)
wait_for_pod_running() {
    local pod_name=$1
    local timeout=${2:-60}
    local namespace=${3:-default}

    print_info "Waiting for pod '$pod_name' to be running..."

    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        local phase=$(kubectl get pod $pod_name --namespace=$namespace -o jsonpath='{.status.phase}' 2>/dev/null)

        if [ "$phase" == "Running" ]; then
            print_success "Pod '$pod_name' is running"
            return 0
        fi

        sleep 2
        elapsed=$((elapsed + 2))
    done

    print_error "Pod '$pod_name' did not start running within ${timeout}s"
    return 1
}

# Check if pod exists
pod_exists() {
    local pod_name=$1
    local namespace=${2:-default}

    kubectl get pod $pod_name --namespace=$namespace > /dev/null 2>&1
    return $?
}

# Delete pod if exists
cleanup_pod() {
    local pod_name=$1
    local namespace=${2:-default}

    if pod_exists $pod_name $namespace; then
        print_info "Cleaning up pod '$pod_name'..."
        kubectl delete pod $pod_name --namespace=$namespace --grace-period=5 > /dev/null 2>&1

        # Wait for deletion
        local timeout=30
        local elapsed=0
        while pod_exists $pod_name $namespace && [ $elapsed -lt $timeout ]; do
            sleep 2
            elapsed=$((elapsed + 2))
        done

        if pod_exists $pod_name $namespace; then
            print_warning "Pod '$pod_name' still exists after ${timeout}s, forcing deletion..."
            kubectl delete pod $pod_name --namespace=$namespace --force --grace-period=0 > /dev/null 2>&1
        else
            print_success "Pod '$pod_name' cleaned up"
        fi
    fi
}

# Delete resource if exists
cleanup_resource() {
    local resource_type=$1
    local resource_name=$2
    local namespace=${3:-default}

    if kubectl get $resource_type $resource_name --namespace=$namespace > /dev/null 2>&1; then
        print_info "Cleaning up $resource_type '$resource_name'..."
        kubectl delete $resource_type $resource_name --namespace=$namespace --grace-period=5 > /dev/null 2>&1
        sleep 2
    fi
}

# Get pod logs
get_pod_logs() {
    local pod_name=$1
    local container_name=$2
    local namespace=${3:-default}
    local lines=${4:-50}

    kubectl logs $pod_name -c $container_name --namespace=$namespace --tail=$lines 2>/dev/null
}

# Execute command in pod
exec_in_pod() {
    local pod_name=$1
    local container_name=$2
    local command=$3
    local namespace=${4:-default}

    kubectl exec $pod_name -c $container_name --namespace=$namespace -- sh -c "$command" 2>/dev/null
}

# Check if container is running in pod
is_container_running() {
    local pod_name=$1
    local container_name=$2
    local namespace=${3:-default}

    local state=$(kubectl get pod $pod_name --namespace=$namespace \
        -o jsonpath="{.status.containerStatuses[?(@.name=='$container_name')].state}" 2>/dev/null)

    if echo "$state" | grep -q "running"; then
        return 0
    else
        return 1
    fi
}

# Get container restart count
get_restart_count() {
    local pod_name=$1
    local container_name=$2
    local namespace=${3:-default}

    kubectl get pod $pod_name --namespace=$namespace \
        -o jsonpath="{.status.containerStatuses[?(@.name=='$container_name')].restartCount}" 2>/dev/null
}

# Run assertion
assert_equals() {
    local actual=$1
    local expected=$2
    local description=$3

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [ "$actual" == "$expected" ]; then
        print_success "PASS: $description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "FAIL: $description"
        print_error "  Expected: $expected"
        print_error "  Actual:   $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Run assertion (not equals)
assert_not_equals() {
    local actual=$1
    local expected=$2
    local description=$3

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [ "$actual" != "$expected" ]; then
        print_success "PASS: $description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "FAIL: $description"
        print_error "  Should not equal: $expected"
        print_error "  Actual:          $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Run assertion (contains)
assert_contains() {
    local haystack=$1
    local needle=$2
    local description=$3

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if echo "$haystack" | grep -q "$needle"; then
        print_success "PASS: $description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "FAIL: $description"
        print_error "  Expected to contain: $needle"
        print_error "  In:                  $haystack"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Run assertion (command succeeds)
assert_success() {
    local command=$1
    local description=$2

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if eval "$command" > /dev/null 2>&1; then
        print_success "PASS: $description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "FAIL: $description"
        print_error "  Command failed: $command"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Print test summary
print_test_summary() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} Test Summary"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC} Total tests:  $TESTS_TOTAL"
    echo -e "${BLUE}║${NC} ${GREEN}Passed:       $TESTS_PASSED${NC}"
    echo -e "${BLUE}║${NC} ${RED}Failed:       $TESTS_FAILED${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        print_success "All tests passed!"
        return 0
    else
        print_error "Some tests failed!"
        return 1
    fi
}

# Check minikube status
check_minikube() {
    print_info "Checking minikube status..."

    if ! command -v minikube &> /dev/null; then
        print_error "minikube is not installed"
        return 1
    fi

    if ! minikube status > /dev/null 2>&1; then
        print_error "minikube is not running. Please start it with: minikube start"
        return 1
    fi

    print_success "minikube is running"
    return 0
}

# Check kubectl connectivity
check_kubectl() {
    print_info "Checking kubectl connectivity..."

    if ! kubectl cluster-info > /dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster"
        return 1
    fi

    print_success "kubectl can connect to cluster"
    return 0
}
