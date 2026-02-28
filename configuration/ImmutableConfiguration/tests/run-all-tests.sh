#!/bin/bash

# Run All Immutable Configuration Tests
# This script executes all test cases sequentially

set -e

SCRIPT_DIR=$(dirname "$0")
source "$SCRIPT_DIR/common.sh"

print_header "Immutable Configuration Pattern - All Tests"

# Check prerequisites
check_kubectl
check_minikube

# Test tracking
TOTAL_TEST_SUITES=5
PASSED_SUITES=0
FAILED_SUITES=0

# Test Suite 1: Basic Init Container
print_header "Running Test Suite 1/5: Basic Init Container"
if bash "$SCRIPT_DIR/test1-basic.sh"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
else
    FAILED_SUITES=$((FAILED_SUITES + 1))
fi

echo ""
echo "Press Enter to continue to next test suite..."
read

# Test Suite 2: Multi-File Configuration
print_header "Running Test Suite 2/5: Multi-File Configuration"
if bash "$SCRIPT_DIR/test2-multi-file.sh"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
else
    FAILED_SUITES=$((FAILED_SUITES + 1))
fi

echo ""
echo "Press Enter to continue to next test suite..."
read

# Test Suite 3: Init Container Failure
print_header "Running Test Suite 3/5: Init Container Failure"
if bash "$SCRIPT_DIR/test3-init-failure.sh"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
else
    FAILED_SUITES=$((FAILED_SUITES + 1))
fi

echo ""
echo "Press Enter to continue to next test suite..."
read

# Test Suite 4: ConfigMap Comparison
print_header "Running Test Suite 4/5: ConfigMap Comparison"
if bash "$SCRIPT_DIR/test4-configmap-comparison.sh"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
else
    FAILED_SUITES=$((FAILED_SUITES + 1))
fi

echo ""
echo "Press Enter to continue to next test suite..."
read

# Test Suite 5: Configuration Rollback
print_header "Running Test Suite 5/5: Configuration Rollback"
if bash "$SCRIPT_DIR/test5-rollback.sh"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
else
    FAILED_SUITES=$((FAILED_SUITES + 1))
fi

# Final Summary
print_header "All Tests Complete - Final Summary"

echo ""
echo "Test Suites Results:"
echo -e "${GREEN}Passed: $PASSED_SUITES / $TOTAL_TEST_SUITES${NC}"
echo -e "${RED}Failed: $FAILED_SUITES / $TOTAL_TEST_SUITES${NC}"
echo ""

if [ $FAILED_SUITES -eq 0 ]; then
    print_success "All test suites passed! 🎉"
    exit 0
else
    print_error "Some test suites failed!"
    exit 1
fi
