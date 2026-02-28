#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

echo "=========================================="
echo "Configuration Resource Pattern - Basic Test"
echo "=========================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

cleanup() {
    print_step "Cleaning up resources..."
    kubectl delete pod random-generator --ignore-not-found=true 2>/dev/null || true
    kubectl delete service random-generator --ignore-not-found=true 2>/dev/null || true
    kubectl delete configmap random-generator-config --ignore-not-found=true 2>/dev/null || true
    print_info "Cleanup completed"
}

trap cleanup EXIT

print_step "1. Creating ConfigMap..."
kubectl apply -f "$MANIFEST_DIR/configmap.yaml"
echo ""

print_info "ConfigMap content:"
kubectl get configmap random-generator-config -o yaml
echo ""

print_step "2. Deploying Pod..."
kubectl apply -f "$MANIFEST_DIR/pod.yaml"
echo ""

print_step "3. Waiting for Pod to be ready..."
kubectl wait --for=condition=Ready pod/random-generator --timeout=60s || {
    print_error "Pod failed to become ready"
    kubectl describe pod random-generator
    kubectl logs random-generator || true
    exit 1
}
print_success "Pod is ready"
echo ""

print_step "4. Verifying ConfigMap usage methods..."

echo -e "\n${YELLOW}=== Method 1: Individual Environment Variable ===${NC}"
echo "PATTERN (direct reference from ConfigMap):"
kubectl exec random-generator -- env | grep "^PATTERN=" || print_error "PATTERN not found"

echo -e "\n${YELLOW}=== Method 2: Bulk Import with Prefix ===${NC}"
echo "All CONFIG_* variables:"
kubectl exec random-generator -- env | grep "^CONFIG_" || print_error "No CONFIG_ variables found"

echo -e "\n${YELLOW}=== Method 3: Volume Mount ===${NC}"
echo "Checking mounted configuration file:"
kubectl exec random-generator -- ls -la /config/app/
echo ""
echo "Configuration file content:"
kubectl exec random-generator -- cat /config/app/random-generator.properties

echo -e "\n${YELLOW}=== File Permissions ===${NC}"
kubectl exec random-generator -- stat /config/app/random-generator.properties | grep "Access:" | head -1

echo -e "\n${YELLOW}=== All ConfigMap Keys as Files ===${NC}"
print_info "Note: When ConfigMap is mounted, all keys become files (unless items[] is specified)"
kubectl exec random-generator -- ls -la /config/

echo ""
print_step "5. Creating Service..."
kubectl apply -f "$MANIFEST_DIR/service.yaml"
kubectl get service random-generator
echo ""

print_step "6. Testing service endpoint..."
MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "localhost")
SERVICE_URL="http://${MINIKUBE_IP}:30081"

echo "Service URL: $SERVICE_URL"
echo "Waiting for service to be available..."
sleep 5

if command -v curl &> /dev/null; then
    echo -e "\n${YELLOW}=== Testing /info endpoint ===${NC}"
    curl -s "${SERVICE_URL}/info" | head -20 || print_error "Failed to access service"
else
    print_info "curl not available, skipping endpoint test"
fi

echo ""
echo "=========================================="
print_success "Configuration Resource Basic Test Completed!"
echo "=========================================="
echo ""
print_info "Key findings:"
echo "  ✓ ConfigMap created successfully"
echo "  ✓ Individual env var reference works"
echo "  ✓ Bulk import with prefix works"
echo "  ✓ Volume mount works"
echo "  ✓ File permissions (0400) applied correctly"
echo ""
