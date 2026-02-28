#!/bin/bash
# Cilium-specific Test Script
# Tests CiliumNetworkPolicy features (L7, DNS-based egress)
#
# Prerequisites:
# - Cilium CNI installed
# - Hubble enabled (optional, for observability)
#
# Usage:
#   ./cilium/test-cilium.sh [test-type]

set -e

NAMESPACE="production"
TIMEOUT=3

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo "=========================================="
    echo -e "${YELLOW}$1${NC}"
    echo "=========================================="
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
}

print_blocked() {
    echo -e "${GREEN}🚫 BLOCKED (expected)${NC}: $1"
}

print_fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
}

# Check Cilium status
check_cilium() {
    print_header "Checking Cilium Installation"

    if ! command -v cilium &> /dev/null; then
        echo "Warning: Cilium CLI not installed. Some tests may be limited."
    else
        cilium status
    fi

    echo ""
    kubectl get pods -n kube-system -l k8s-app=cilium
}

# Test L7 HTTP policy
test_l7_http() {
    print_header "Testing L7 HTTP Policy"

    local pod=$(kubectl get pod -n $NAMESPACE -l role=random-client -o jsonpath='{.items[0].metadata.name}')

    if [ -z "$pod" ]; then
        echo "Error: No pod with role=random-client found"
        return 1
    fi

    echo "Testing from pod: $pod"
    echo ""

    # Test GET request (should succeed)
    echo -n "GET /: "
    result=$(kubectl exec -n $NAMESPACE $pod -- curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT http://random-generator:8080/ 2>/dev/null || echo "timeout")
    if [ "$result" != "timeout" ] && [ "$result" != "000" ]; then
        print_success "HTTP $result"
    else
        print_fail "Connection failed"
    fi

    # Test GET /health (should succeed)
    echo -n "GET /health: "
    result=$(kubectl exec -n $NAMESPACE $pod -- curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT http://random-generator:8080/health 2>/dev/null || echo "timeout")
    if [ "$result" != "timeout" ] && [ "$result" != "000" ] && [ "$result" != "403" ]; then
        print_success "HTTP $result"
    else
        print_fail "Connection failed or blocked"
    fi

    # Test POST request (should be blocked by L7 policy)
    echo -n "POST /: "
    result=$(kubectl exec -n $NAMESPACE $pod -- curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT -X POST http://random-generator:8080/ 2>/dev/null || echo "timeout")
    if [ "$result" = "403" ] || [ "$result" = "timeout" ]; then
        print_blocked "POST request blocked"
    else
        echo -e "${YELLOW}⚠️  HTTP $result (may need L7 policy applied)${NC}"
    fi

    # Test DELETE request (should be blocked by L7 policy)
    echo -n "DELETE /: "
    result=$(kubectl exec -n $NAMESPACE $pod -- curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT -X DELETE http://random-generator:8080/ 2>/dev/null || echo "timeout")
    if [ "$result" = "403" ] || [ "$result" = "timeout" ]; then
        print_blocked "DELETE request blocked"
    else
        echo -e "${YELLOW}⚠️  HTTP $result (may need L7 policy applied)${NC}"
    fi
}

# Test DNS-based egress
test_dns_egress() {
    print_header "Testing DNS-based Egress Policy"

    local pod=$(kubectl get pod -n $NAMESPACE -l app=random-generator -o jsonpath='{.items[0].metadata.name}')

    if [ -z "$pod" ]; then
        echo "Error: No random-generator pod found"
        return 1
    fi

    echo "Testing from pod: $pod"
    print_info "Note: DNS-based egress requires CiliumNetworkPolicy with toFQDNs"
    echo ""

    # Test allowed domain (if policy applied)
    echo -n "Access to api.github.com: "
    result=$(kubectl exec -n $NAMESPACE $pod -- curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT https://api.github.com 2>/dev/null || echo "timeout")
    if [ "$result" != "timeout" ] && [ "$result" != "000" ]; then
        print_success "HTTP $result (allowed domain)"
    else
        echo -e "${YELLOW}Blocked or timeout (check DNS policy)${NC}"
    fi

    # Test blocked domain
    echo -n "Access to example.com: "
    result=$(kubectl exec -n $NAMESPACE $pod -- curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT https://example.com 2>/dev/null || echo "timeout")
    if [ "$result" = "timeout" ] || [ "$result" = "000" ]; then
        print_blocked "Unlisted domain blocked"
    else
        echo -e "${YELLOW}HTTP $result (may need DNS egress policy)${NC}"
    fi
}

# Test with Hubble
test_hubble() {
    print_header "Testing with Hubble Observability"

    if ! command -v hubble &> /dev/null; then
        print_info "Hubble CLI not installed. Install with: cilium hubble enable"
        print_info "Then: brew install hubble (macOS) or download from GitHub"
        return
    fi

    echo "Starting Hubble port-forward in background..."
    cilium hubble port-forward &
    HUBBLE_PID=$!
    sleep 2

    echo "Observing network flows in $NAMESPACE namespace:"
    echo "(Press Ctrl+C to stop)"
    echo ""

    hubble observe --namespace $NAMESPACE --last 10

    kill $HUBBLE_PID 2>/dev/null || true
}

# Show Cilium policies
show_policies() {
    print_header "Cilium Network Policies"

    echo "Standard NetworkPolicies:"
    kubectl get networkpolicies -n $NAMESPACE

    echo ""
    echo "CiliumNetworkPolicies:"
    kubectl get ciliumnetworkpolicies -n $NAMESPACE 2>/dev/null || echo "No CiliumNetworkPolicies found"

    echo ""
    echo "CiliumClusterwideNetworkPolicies:"
    kubectl get ciliumclusterwidenetworkpolicies 2>/dev/null || echo "No cluster-wide policies found"
}

# Main
case "$1" in
    status)
        check_cilium
        ;;
    l7)
        test_l7_http
        ;;
    dns)
        test_dns_egress
        ;;
    hubble)
        test_hubble
        ;;
    policies)
        show_policies
        ;;
    all)
        check_cilium
        test_l7_http
        test_dns_egress
        show_policies
        ;;
    *)
        echo "Cilium Network Policy Test Script"
        echo ""
        echo "Usage: $0 {status|l7|dns|hubble|policies|all}"
        echo ""
        echo "Commands:"
        echo "  status    - Check Cilium installation status"
        echo "  l7        - Test L7 HTTP policies (method/path filtering)"
        echo "  dns       - Test DNS-based egress policies"
        echo "  hubble    - Test with Hubble observability"
        echo "  policies  - Show all Cilium network policies"
        echo "  all       - Run all tests"
        echo ""
        echo "Prerequisites:"
        echo "  1. Cilium CNI installed: ./00-setup-cilium.sh"
        echo "  2. Test apps deployed: kubectl apply -f 05-3tier-app-deployment.yaml"
        echo "  3. Cilium policies applied: kubectl apply -f cilium/"
        exit 1
        ;;
esac

echo ""
echo "Test completed."
