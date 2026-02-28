#!/bin/bash
# Run all Ambassador pattern tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities
source "$SCRIPT_DIR/test-utils.sh"

# Test result tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Result file
RESULT_FILE="$SCRIPT_DIR/../test-results.md"

# Print banner
print_banner() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                              ║${NC}"
    echo -e "${BLUE}║           Ambassador Pattern - Test Suite                   ║${NC}"
    echo -e "${BLUE}║                                                              ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Run single test
run_single_test() {
    local test_script=$1
    local test_name=$2

    echo ""
    print_info "========================================"
    print_info "Running: $test_name"
    print_info "========================================"
    echo ""

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if bash "$test_script"; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        print_success "$test_name - PASSED"
        return 0
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        print_error "$test_name - FAILED"
        return 1
    fi
}

# Generate results markdown
generate_results() {
    local end_time=$(date '+%Y-%m-%d %H:%M:%S')

    cat > "$RESULT_FILE" << EOF
# Ambassador Pattern - Test Results

## Test Execution Summary

- **Date**: $end_time
- **Total Tests**: $TOTAL_TESTS
- **Passed**: $PASSED_TESTS
- **Failed**: $FAILED_TESTS
- **Success Rate**: $(( PASSED_TESTS * 100 / TOTAL_TESTS ))%

## Test Details

EOF

    if [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
        echo "### ✓ All Tests Passed!" >> "$RESULT_FILE"
        echo "" >> "$RESULT_FILE"
    else
        echo "### ⚠ Some Tests Failed" >> "$RESULT_FILE"
        echo "" >> "$RESULT_FILE"
    fi

    cat >> "$RESULT_FILE" << EOF
| Test # | Test Name | Status |
|--------|-----------|--------|
| 1 | Basic Ambassador Pattern - Log Proxy | ${test1_status} |
| 2 | Localhost Communication Verification | ${test2_status} |
| 3 | HTTP Proxy Ambassador | ${test3_status} |
| 4 | Environment-specific Backend Switching | ${test4_status} |
| 5 | Ambassador Failure Recovery | ${test5_status} |
| 6 | Native Sidecar Startup Order | ${test6_status} |
| 7 | Resource Isolation and Security | ${test7_status} |

## Test Descriptions

### Test 1: Basic Ambassador Pattern - Log Proxy
Verifies the basic Ambassador pattern where a sidecar container proxies logs from the main application.

**Validated**:
- Pod with multiple containers runs successfully
- Main container communicates with ambassador via localhost
- External access to main application works

### Test 2: Localhost Communication Verification
Confirms that containers within the same Pod can communicate via localhost due to shared network namespace.

**Validated**:
- Containers share network namespace
- localhost communication works
- No external network required for inter-container communication

### Test 3: HTTP Proxy Ambassador
Tests Nginx as an ambassador that proxies external HTTP services.

**Validated**:
- Ambassador proxies external services
- Main app accesses external APIs via localhost
- Timeout and retry policies work

### Test 4: Environment-specific Backend Switching
Demonstrates how the same application code can work with different backends using different ambassadors.

**Validated**:
- Same application code in dev and prod
- Dev uses simple local cache
- Prod uses HAProxy load-balancing to multiple Redis instances
- Proper separation of concerns

### Test 5: Ambassador Failure Recovery
Verifies that ambassador containers automatically restart on failure.

**Validated**:
- Ambassador restarts automatically on crash
- Main application resumes communication after recovery
- No data loss during ambassador restart

### Test 6: Native Sidecar Startup Order
Tests Kubernetes 1.28+ Native Sidecar feature with restartPolicy: Always.

**Validated**:
- Native Sidecar starts before main container
- startupProbe ensures ambassador readiness
- Proper startup sequencing

### Test 7: Resource Isolation and Security
Validates security contexts and resource isolation.

**Validated**:
- Non-root execution enforced
- Resource limits applied
- NetworkPolicy restricts direct external access
- Ambassador provides security layer

## Kubernetes Environment

\`\`\`
$(kubectl version --short 2>/dev/null || kubectl version)
\`\`\`

## Minikube Status

\`\`\`
$(minikube status 2>/dev/null || echo "Minikube status unavailable")
\`\`\`

## Notes

- Tests were designed for minikube environment
- Some tests may require specific Kubernetes versions or features
- NetworkPolicy tests require a network plugin that supports policies
- Native Sidecar tests require Kubernetes 1.28+

---

Generated by Ambassador Pattern Test Suite
EOF

    print_success "Test results written to: $RESULT_FILE"
}

# Main execution
main() {
    print_banner

    # Check prerequisites
    print_info "Checking prerequisites..."
    if ! check_minikube; then
        print_error "Minikube is not running. Please start minikube first."
        exit 1
    fi

    if ! check_kubectl; then
        print_error "Cannot connect to Kubernetes cluster."
        exit 1
    fi

    print_success "Prerequisites checked successfully"
    echo ""

    # Get Kubernetes version
    print_info "Kubernetes cluster information:"
    kubectl version --short 2>/dev/null || kubectl version | head -2
    echo ""

    # Ask user if they want to run all tests
    read -p "Run all tests? This will create/delete pods in your cluster. (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Test execution cancelled by user"
        exit 0
    fi

    local start_time=$(date '+%Y-%m-%d %H:%M:%S')
    print_info "Test execution started at: $start_time"
    echo ""

    # Run tests
    test1_status="❌ FAILED"
    test2_status="❌ FAILED"
    test3_status="❌ FAILED"
    test4_status="❌ FAILED"
    test5_status="❌ FAILED"
    test6_status="❌ FAILED"
    test7_status="❌ FAILED"

    if run_single_test "$SCRIPT_DIR/test1-basic.sh" "Test 1: Basic Ambassador Pattern"; then
        test1_status="✅ PASSED"
    fi

    if run_single_test "$SCRIPT_DIR/test2-localhost.sh" "Test 2: Localhost Communication"; then
        test2_status="✅ PASSED"
    fi

    if run_single_test "$SCRIPT_DIR/test3-http-proxy.sh" "Test 3: HTTP Proxy Ambassador"; then
        test3_status="✅ PASSED"
    fi

    if run_single_test "$SCRIPT_DIR/test4-env-backend.sh" "Test 4: Environment Backend Switching"; then
        test4_status="✅ PASSED"
    fi

    if run_single_test "$SCRIPT_DIR/test5-failure.sh" "Test 5: Failure Recovery"; then
        test5_status="✅ PASSED"
    fi

    if run_single_test "$SCRIPT_DIR/test6-native-sidecar.sh" "Test 6: Native Sidecar"; then
        test6_status="✅ PASSED"
    fi

    if run_single_test "$SCRIPT_DIR/test7-security.sh" "Test 7: Security"; then
        test7_status="✅ PASSED"
    fi

    # Print final summary
    echo ""
    echo ""
    print_header "FINAL TEST SUMMARY"

    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} Test Execution Results                                     ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC} Total Tests:    $TOTAL_TESTS                                           ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} ${GREEN}Passed:         $PASSED_TESTS${NC}                                           ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} ${RED}Failed:         $FAILED_TESTS${NC}                                           ${BLUE}║${NC}"

    if [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
        echo -e "${BLUE}║${NC}                                                              ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${GREEN}🎉 All tests passed successfully!${NC}                        ${BLUE}║${NC}"
    else
        echo -e "${BLUE}║${NC}                                                              ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${RED}⚠  Some tests failed. Please review the logs above.${NC}      ${BLUE}║${NC}"
    fi

    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Generate results file
    generate_results

    echo ""
    print_info "Detailed test results available in: $RESULT_FILE"
    echo ""

    # Return success if all tests passed
    if [ $FAILED_TESTS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Run main
main "$@"
