#!/bin/bash
# Network Connectivity Test Script
# Tests network policies by attempting connections between pods
#
# Usage:
#   ./test-connectivity.sh [phase]
#
# Phases:
#   before    - Test before applying any NetworkPolicies
#   after     - Test after applying deny-all
#   egress    - Test egress policies
#   3tier     - Test 3-tier architecture policies
#   all       - Run all tests

set -e

NAMESPACE="production"
TIMEOUT=3

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo "=========================================="
    echo -e "${YELLOW}$1${NC}"
    echo "=========================================="
}

print_success() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
}

print_fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
}

print_blocked() {
    echo -e "${GREEN}🚫 BLOCKED (expected)${NC}: $1"
}

print_unexpected() {
    echo -e "${RED}⚠️  UNEXPECTED${NC}: $1"
}

# Wait for pods to be ready
wait_for_pods() {
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=Ready pods --all -n $NAMESPACE --timeout=120s
}

# Get pod name by app label
get_pod() {
    kubectl get pod -n $NAMESPACE -l app=$1 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

# Test HTTP connection
test_http() {
    local from_pod=$1
    local to_service=$2
    local port=$3
    local expected=$4
    local description=$5

    echo -n "Testing: $description... "

    result=$(kubectl exec -n $NAMESPACE $from_pod -- curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT http://${to_service}:${port}/ 2>/dev/null || echo "timeout")

    if [ "$expected" = "success" ]; then
        if [ "$result" != "timeout" ] && [ "$result" != "000" ]; then
            print_success "HTTP $result"
        else
            print_unexpected "Connection timed out (expected success)"
        fi
    else
        if [ "$result" = "timeout" ] || [ "$result" = "000" ]; then
            print_blocked "$description"
        else
            print_unexpected "Connection succeeded (expected blocked)"
        fi
    fi
}

# Test TCP connection
test_tcp() {
    local from_pod=$1
    local to_service=$2
    local port=$3
    local expected=$4
    local description=$5

    echo -n "Testing: $description... "

    # Try nc command
    result=$(kubectl exec -n $NAMESPACE $from_pod -- sh -c "nc -zv -w $TIMEOUT $to_service $port 2>&1" 2>/dev/null || echo "failed")

    if [ "$expected" = "success" ]; then
        if echo "$result" | grep -q "succeeded\|open\|Connected"; then
            print_success "TCP connection established"
        else
            print_unexpected "Connection failed (expected success)"
        fi
    else
        if echo "$result" | grep -q "timed out\|refused\|failed"; then
            print_blocked "$description"
        else
            print_unexpected "Connection succeeded (expected blocked)"
        fi
    fi
}

# Test DNS resolution
test_dns() {
    local from_pod=$1
    local hostname=$2
    local expected=$3

    echo -n "Testing: DNS resolution for $hostname... "

    result=$(kubectl exec -n $NAMESPACE $from_pod -- nslookup $hostname 2>&1 || echo "failed")

    if [ "$expected" = "success" ]; then
        if echo "$result" | grep -q "Address"; then
            print_success "DNS resolved"
        else
            print_unexpected "DNS resolution failed (expected success)"
        fi
    else
        if echo "$result" | grep -q "can't resolve\|timed out\|failed"; then
            print_blocked "DNS resolution"
        else
            print_unexpected "DNS resolved (expected blocked)"
        fi
    fi
}

# Test external connection
test_external() {
    local from_pod=$1
    local url=$2
    local expected=$3

    echo -n "Testing: External access to $url... "

    result=$(kubectl exec -n $NAMESPACE $from_pod -- curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT $url 2>/dev/null || echo "timeout")

    if [ "$expected" = "success" ]; then
        if [ "$result" != "timeout" ] && [ "$result" != "000" ]; then
            print_success "HTTP $result"
        else
            print_unexpected "Connection timed out (expected success)"
        fi
    else
        if [ "$result" = "timeout" ] || [ "$result" = "000" ]; then
            print_blocked "External access"
        else
            print_unexpected "Connection succeeded (expected blocked)"
        fi
    fi
}

# Phase: Before NetworkPolicies
test_before() {
    print_header "Phase: Before NetworkPolicies (All connections should work)"

    wait_for_pods

    local curl_pod=$(get_pod "curl-client")
    local curl_labeled_pod=$(get_pod "curl-client-labeled")

    if [ -z "$curl_pod" ]; then
        echo "Error: curl-client pod not found"
        exit 1
    fi

    test_http "$curl_pod" "random-generator" 8080 "success" "curl-client -> random-generator"
    test_http "$curl_pod" "frontend" 80 "success" "curl-client -> frontend"
    test_tcp "$curl_pod" "database" 5432 "success" "curl-client -> database"
    test_external "$curl_pod" "https://google.com" "success" "curl-client -> internet"
}

# Phase: After deny-all
test_after_deny() {
    print_header "Phase: After Deny-All (All connections should be blocked)"

    local curl_pod=$(get_pod "curl-client")

    test_http "$curl_pod" "random-generator" 8080 "blocked" "curl-client -> random-generator"
    test_http "$curl_pod" "frontend" 80 "blocked" "curl-client -> frontend"
    test_tcp "$curl_pod" "database" 5432 "blocked" "curl-client -> database"
}

# Phase: After allow-labeled-access
test_after_allow() {
    print_header "Phase: After Allow-Labeled-Access"

    local curl_pod=$(get_pod "curl-client")
    local curl_labeled_pod=$(get_pod "curl-client-labeled")

    echo "curl-client (no label) - should be blocked:"
    test_http "$curl_pod" "random-generator" 8080 "blocked" "curl-client -> random-generator"

    echo ""
    echo "curl-client-labeled (has role: random-client) - should work:"
    test_http "$curl_labeled_pod" "random-generator" 8080 "success" "curl-client-labeled -> random-generator"
}

# Phase: Egress tests
test_egress() {
    print_header "Phase: Egress Policy Tests"

    local curl_pod=$(get_pod "curl-client")

    echo "Testing DNS resolution:"
    test_dns "$curl_pod" "kubernetes.default" "success"

    echo ""
    echo "Testing internal egress:"
    test_http "$curl_pod" "random-generator" 8080 "success" "curl-client -> random-generator (internal)"

    echo ""
    echo "Testing external egress (should be blocked if egress policy applied):"
    test_external "$curl_pod" "https://google.com" "blocked" "curl-client -> internet"
}

# Phase: 3-tier architecture
test_3tier() {
    print_header "Phase: 3-Tier Architecture Tests"

    local frontend_pod=$(get_pod "frontend")
    local curl_labeled_pod=$(get_pod "curl-client-labeled")
    local curl_pod=$(get_pod "curl-client")

    echo "=== Allowed Paths ==="
    echo "Frontend -> Backend (should work):"
    test_http "$frontend_pod" "random-generator" 8080 "success" "frontend -> random-generator"

    echo ""
    echo "Labeled client -> Backend (should work):"
    test_http "$curl_labeled_pod" "random-generator" 8080 "success" "curl-client-labeled -> random-generator"

    echo ""
    echo "=== Blocked Paths ==="
    echo "Unlabeled client -> Backend (should be blocked):"
    test_http "$curl_pod" "random-generator" 8080 "blocked" "curl-client -> random-generator"

    echo ""
    echo "Frontend -> Database direct (should be blocked):"
    test_tcp "$frontend_pod" "database" 5432 "blocked" "frontend -> database"

    echo ""
    echo "Client -> Database (should be blocked):"
    test_tcp "$curl_pod" "database" 5432 "blocked" "curl-client -> database"
}

# Show current NetworkPolicies
show_policies() {
    print_header "Current NetworkPolicies"
    kubectl get networkpolicies -n $NAMESPACE -o wide
}

# Main
case "$1" in
    before)
        test_before
        ;;
    after|after-deny)
        test_after_deny
        ;;
    after-allow)
        test_after_allow
        ;;
    egress)
        test_egress
        ;;
    3tier)
        test_3tier
        ;;
    policies)
        show_policies
        ;;
    all)
        test_before
        echo ""
        echo "Now apply NetworkPolicies and run individual phase tests"
        ;;
    *)
        echo "Usage: $0 {before|after-deny|after-allow|egress|3tier|policies|all}"
        echo ""
        echo "Phases:"
        echo "  before      - Test before applying any NetworkPolicies"
        echo "  after-deny  - Test after applying deny-all policy"
        echo "  after-allow - Test after applying allow-labeled-access policy"
        echo "  egress      - Test egress policies"
        echo "  3tier       - Test complete 3-tier architecture"
        echo "  policies    - Show current NetworkPolicies"
        echo "  all         - Run initial test (before phase)"
        exit 1
        ;;
esac

echo ""
echo "Test completed."
