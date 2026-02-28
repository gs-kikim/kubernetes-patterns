#!/bin/bash

# RBAC Access Control Pattern Test Script
# This script tests various RBAC scenarios in Kubernetes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo "========================================"
    echo -e "${YELLOW}$1${NC}"
    echo "========================================"
}

print_test() {
    echo -e "\n[TEST] $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

print_info() {
    echo -e "[INFO] $1"
}

# Cleanup function
cleanup() {
    print_header "Cleanup"
    kubectl delete -f "$SCRIPT_DIR/" --ignore-not-found=true 2>/dev/null || true
    kubectl delete clusterrolebinding app-sa-view-nodes --ignore-not-found=true 2>/dev/null || true
    kubectl delete clusterrole view-pods view-nodes --ignore-not-found=true 2>/dev/null || true
    kubectl delete namespace rbac-test rbac-test-2 --ignore-not-found=true 2>/dev/null || true
    print_info "Cleanup completed"
}

print_header "RBAC Access Control Pattern Tests"
print_info "Starting RBAC tests on minikube..."

# ============================================
# Step 1: Apply all resources
# ============================================
print_header "Step 1: Applying RBAC Resources"

print_info "Creating namespaces..."
kubectl apply -f "$SCRIPT_DIR/01-namespace.yaml"

print_info "Creating ServiceAccounts..."
kubectl apply -f "$SCRIPT_DIR/02-serviceaccount.yaml"

print_info "Creating Roles..."
kubectl apply -f "$SCRIPT_DIR/03-role.yaml"

print_info "Creating RoleBindings..."
kubectl apply -f "$SCRIPT_DIR/04-rolebinding.yaml"

print_info "Creating ClusterRoles..."
kubectl apply -f "$SCRIPT_DIR/05-clusterrole.yaml"

print_info "Creating ClusterRoleBindings..."
kubectl apply -f "$SCRIPT_DIR/06-clusterrolebinding.yaml"

print_info "Creating test Pods..."
kubectl apply -f "$SCRIPT_DIR/07-test-pods.yaml"

# Wait for pods to be ready
print_info "Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pod/api-test -n rbac-test --timeout=60s 2>/dev/null || true
kubectl wait --for=condition=Ready pod/sample-pod -n rbac-test-2 --timeout=60s 2>/dev/null || true

# ============================================
# Step 2: Test kubectl auth can-i
# ============================================
print_header "Step 2: Testing kubectl auth can-i"

# Test 2.1: app-sa can list pods in rbac-test namespace
print_test "2.1: app-sa can list pods in rbac-test namespace"
RESULT=$(kubectl auth can-i list pods --namespace rbac-test --as system:serviceaccount:rbac-test:app-sa 2>&1)
if [ "$RESULT" == "yes" ]; then
    print_pass "app-sa can list pods in rbac-test"
else
    print_fail "app-sa cannot list pods in rbac-test (expected: yes, got: $RESULT)"
fi

# Test 2.2: app-sa can get pod logs in rbac-test namespace
print_test "2.2: app-sa can get pod logs in rbac-test namespace"
RESULT=$(kubectl auth can-i get pods/log --namespace rbac-test --as system:serviceaccount:rbac-test:app-sa 2>&1)
if [ "$RESULT" == "yes" ]; then
    print_pass "app-sa can get pod logs in rbac-test"
else
    print_fail "app-sa cannot get pod logs in rbac-test (expected: yes, got: $RESULT)"
fi

# Test 2.3: app-sa cannot delete pods in rbac-test namespace
print_test "2.3: app-sa cannot delete pods in rbac-test namespace"
RESULT=$(kubectl auth can-i delete pods --namespace rbac-test --as system:serviceaccount:rbac-test:app-sa 2>&1)
if [ "$RESULT" == "no" ]; then
    print_pass "app-sa cannot delete pods (as expected)"
else
    print_fail "app-sa can delete pods (expected: no, got: $RESULT)"
fi

# Test 2.4: app-sa cannot list secrets in rbac-test namespace (not bound to secret-reader)
print_test "2.4: app-sa cannot list secrets in rbac-test namespace"
RESULT=$(kubectl auth can-i list secrets --namespace rbac-test --as system:serviceaccount:rbac-test:app-sa 2>&1)
if [ "$RESULT" == "no" ]; then
    print_pass "app-sa cannot list secrets (as expected)"
else
    print_fail "app-sa can list secrets (expected: no, got: $RESULT)"
fi

# Test 2.5: app-sa can view nodes (ClusterRoleBinding)
print_test "2.5: app-sa can view nodes (via ClusterRoleBinding)"
RESULT=$(kubectl auth can-i list nodes --as system:serviceaccount:rbac-test:app-sa 2>&1 | grep -E "^yes$|^no$" | head -1)
if [ "$RESULT" == "yes" ]; then
    print_pass "app-sa can list nodes"
else
    print_fail "app-sa cannot list nodes (expected: yes, got: $RESULT)"
fi

# Test 2.6: app-sa can list pods in rbac-test-2 (ClusterRole via RoleBinding)
print_test "2.6: app-sa can list pods in rbac-test-2 (ClusterRole via RoleBinding)"
RESULT=$(kubectl auth can-i list pods --namespace rbac-test-2 --as system:serviceaccount:rbac-test:app-sa 2>&1)
if [ "$RESULT" == "yes" ]; then
    print_pass "app-sa can list pods in rbac-test-2"
else
    print_fail "app-sa cannot list pods in rbac-test-2 (expected: yes, got: $RESULT)"
fi

# Test 2.7: app-sa cannot list pods in kube-system
print_test "2.7: app-sa cannot list pods in kube-system"
RESULT=$(kubectl auth can-i list pods --namespace kube-system --as system:serviceaccount:rbac-test:app-sa 2>&1)
if [ "$RESULT" == "no" ]; then
    print_pass "app-sa cannot list pods in kube-system (as expected)"
else
    print_fail "app-sa can list pods in kube-system (expected: no, got: $RESULT)"
fi

# ============================================
# Step 3: Test API access from Pod
# ============================================
print_header "Step 3: Testing API Access from Pod"

# Check if api-test pod is running
if kubectl get pod api-test -n rbac-test -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Running"; then

    # Test 3.1: List pods via API (should succeed)
    print_test "3.1: API call to list pods (should succeed)"
    API_RESULT=$(kubectl exec -n rbac-test api-test -- sh -c '
        TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
        CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        curl -s --cacert $CACERT \
            -H "Authorization: Bearer $TOKEN" \
            -o /dev/null -w "%{http_code}" \
            https://kubernetes.default.svc/api/v1/namespaces/rbac-test/pods
    ' 2>&1)
    if [ "$API_RESULT" == "200" ]; then
        print_pass "API call to list pods returned 200"
    else
        print_fail "API call to list pods failed (expected: 200, got: $API_RESULT)"
    fi

    # Test 3.2: List secrets via API (should fail with 403)
    print_test "3.2: API call to list secrets (should fail with 403)"
    API_RESULT=$(kubectl exec -n rbac-test api-test -- sh -c '
        TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
        CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        curl -s --cacert $CACERT \
            -H "Authorization: Bearer $TOKEN" \
            -o /dev/null -w "%{http_code}" \
            https://kubernetes.default.svc/api/v1/namespaces/rbac-test/secrets
    ' 2>&1)
    if [ "$API_RESULT" == "403" ]; then
        print_pass "API call to list secrets returned 403 (forbidden)"
    else
        print_fail "API call to list secrets unexpected result (expected: 403, got: $API_RESULT)"
    fi

    # Test 3.3: List nodes via API (should succeed via ClusterRoleBinding)
    print_test "3.3: API call to list nodes (should succeed via ClusterRoleBinding)"
    API_RESULT=$(kubectl exec -n rbac-test api-test -- sh -c '
        TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
        CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        curl -s --cacert $CACERT \
            -H "Authorization: Bearer $TOKEN" \
            -o /dev/null -w "%{http_code}" \
            https://kubernetes.default.svc/api/v1/nodes
    ' 2>&1)
    if [ "$API_RESULT" == "200" ]; then
        print_pass "API call to list nodes returned 200"
    else
        print_fail "API call to list nodes failed (expected: 200, got: $API_RESULT)"
    fi
else
    print_info "Skipping Pod API tests - api-test pod not running"
fi

# ============================================
# Step 4: Test Bound Service Account Token
# ============================================
print_header "Step 4: Testing Bound Service Account Token"

if kubectl get pod api-test -n rbac-test -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Running"; then

    # Test 4.1: Verify token exists and has JWT structure
    print_test "4.1: Verify token exists and has JWT structure"
    TOKEN_CHECK=$(kubectl exec -n rbac-test api-test -- sh -c '
        TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
        # JWT tokens have 3 parts separated by dots
        PARTS=$(echo "$TOKEN" | tr "." "\n" | wc -l)
        if [ "$PARTS" -eq 3 ]; then
            echo "valid_jwt"
        else
            echo "invalid"
        fi
    ' 2>&1 || true)
    if echo "$TOKEN_CHECK" | grep -q "valid_jwt"; then
        print_pass "Token has valid JWT structure (3 parts)"
    else
        print_fail "Token structure verification failed"
    fi

    # Test 4.2: Verify token contains service account info
    print_test "4.2: Verify token contains service account info"
    SA_CHECK=$(kubectl exec -n rbac-test api-test -- sh -c '
        cat /var/run/secrets/kubernetes.io/serviceaccount/token | cut -d. -f2 | base64 -d 2>/dev/null
    ' 2>&1 || true)
    if echo "$SA_CHECK" | grep -q "app-sa"; then
        print_pass "Token contains service account name (app-sa)"
    else
        print_fail "Token does not contain expected service account name"
    fi
else
    print_info "Skipping token tests - api-test pod not running"
fi

# ============================================
# Step 5: Test automountServiceAccountToken: false
# ============================================
print_header "Step 5: Testing automountServiceAccountToken: false"

# Wait for no-token-test pod
kubectl wait --for=condition=Ready pod/no-token-test -n rbac-test --timeout=60s 2>/dev/null || true

if kubectl get pod no-token-test -n rbac-test -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Running"; then

    print_test "5.1: Verify no token mounted in no-token-sa pod"
    TOKEN_EXISTS=$(kubectl exec -n rbac-test no-token-test -- sh -c '
        if [ -f /var/run/secrets/kubernetes.io/serviceaccount/token ]; then
            echo "exists"
        else
            echo "not_exists"
        fi
    ' 2>&1 || echo "not_exists")

    if [ "$TOKEN_EXISTS" == "not_exists" ]; then
        print_pass "Token not mounted (automountServiceAccountToken: false works)"
    else
        print_fail "Token was mounted even with automountServiceAccountToken: false"
    fi
else
    print_info "Skipping no-token test - no-token-test pod not running"
fi

# ============================================
# Summary
# ============================================
print_header "Test Summary"
echo ""
echo -e "Passed: ${GREEN}$PASS_COUNT${NC}"
echo -e "Failed: ${RED}$FAIL_COUNT${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
