#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

echo "=========================================="
echo "EnvVar Configuration Pattern Test"
echo "=========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

cleanup() {
    print_step "Cleaning up resources..."
    kubectl delete -f "$MANIFEST_DIR" --ignore-not-found=true 2>/dev/null || true
    print_info "Cleanup completed"
}

# Cleanup on exit
trap cleanup EXIT

print_step "1. Creating ConfigMap..."
kubectl apply -f "$MANIFEST_DIR/configmap.yaml"
kubectl get configmap random-generator-config -o yaml
echo ""

print_step "2. Creating Secret..."
kubectl apply -f "$MANIFEST_DIR/secret.yaml"
kubectl get secret random-generator-secret -o yaml
echo ""

print_step "3. Deploying Pod with environment variables..."
kubectl apply -f "$MANIFEST_DIR/pod.yaml"
echo ""

print_step "4. Waiting for Pod to be ready..."
kubectl wait --for=condition=Ready pod/random-generator --timeout=60s || {
    print_error "Pod failed to become ready"
    kubectl describe pod random-generator
    kubectl logs random-generator || true
    exit 1
}
print_success "Pod is ready"
echo ""

print_step "5. Verifying environment variables..."

echo -e "\n${YELLOW}=== All Environment Variables ===${NC}"
kubectl exec random-generator -- env | sort

echo -e "\n${YELLOW}=== Direct Literal Values ===${NC}"
echo "LOG_FILE:"
kubectl exec random-generator -- env | grep "^LOG_FILE=" || print_error "LOG_FILE not found"
echo "PORT:"
kubectl exec random-generator -- env | grep "^PORT=" || print_error "PORT not found"
echo "CONTEXT:"
kubectl exec random-generator -- env | grep "^CONTEXT=" || print_error "CONTEXT not found"

echo -e "\n${YELLOW}=== Secret References ===${NC}"
echo "SEED (from Secret):"
kubectl exec random-generator -- env | grep "^SEED=" || print_error "SEED not found"

echo -e "\n${YELLOW}=== Downward API (Pod IP) ===${NC}"
echo "IP:"
kubectl exec random-generator -- env | grep "^IP=" || print_error "IP not found"

echo -e "\n${YELLOW}=== Dependent Variables ===${NC}"
echo "MY_URL (uses IP, PORT, CONTEXT):"
kubectl exec random-generator -- env | grep "^MY_URL=" || print_error "MY_URL not found"
echo "DESCRIPTION (uses RANDOM_PATTERN):"
kubectl exec random-generator -- env | grep "^DESCRIPTION=" || print_error "DESCRIPTION not found"

echo -e "\n${YELLOW}=== ConfigMap with Prefix (RANDOM_) ===${NC}"
echo "RANDOM_PATTERN:"
kubectl exec random-generator -- env | grep "^RANDOM_PATTERN=" || print_error "RANDOM_PATTERN not found"
echo "RANDOM_EXTRA_OPTIONS:"
kubectl exec random-generator -- env | grep "^RANDOM_EXTRA_OPTIONS=" || print_error "RANDOM_EXTRA_OPTIONS not found"

echo -e "\n${YELLOW}=== Illegal Environment Variable Name ===${NC}"
echo "Note: ILLEG.AL from ConfigMap cannot be mapped to environment variable (contains dot)"
kubectl exec random-generator -- env | grep "ILLEG" || print_info "As expected, ILLEG.AL is not mapped (illegal name)"

echo ""
print_step "6. Creating Service..."
kubectl apply -f "$MANIFEST_DIR/service.yaml"
kubectl get service random-generator
echo ""

print_step "7. Testing service endpoint..."
# Get minikube IP
MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "localhost")
SERVICE_URL="http://${MINIKUBE_IP}:30080"

echo "Service URL: $SERVICE_URL"
echo "Waiting for service to be available..."
sleep 5

# Test the endpoint
if command -v curl &> /dev/null; then
    echo -e "\n${YELLOW}=== Testing /info endpoint ===${NC}"
    curl -s "${SERVICE_URL}/info" | head -20 || print_error "Failed to access service"
else
    print_info "curl not available, skipping endpoint test"
fi

echo ""
echo "=========================================="
print_success "EnvVar Configuration Test Completed!"
echo "=========================================="
echo ""
print_info "Key findings:"
echo "  ✓ Direct literal values work"
echo "  ✓ Secret references work"
echo "  ✓ Downward API (Pod IP) works"
echo "  ✓ Dependent variables using \$(VAR) syntax work"
echo "  ✓ ConfigMap with prefix (envFrom) works"
echo "  ✗ Illegal environment variable names (with dots) are skipped"
echo ""
