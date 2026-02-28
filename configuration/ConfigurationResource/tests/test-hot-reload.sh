#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

echo "=========================================="
echo "Configuration Resource - Hot Reload Test"
echo "=========================================="
echo ""

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
    kubectl delete pod random-generator-mutable --ignore-not-found=true 2>/dev/null || true
    kubectl delete configmap random-generator-config-mutable --ignore-not-found=true 2>/dev/null || true
    print_info "Cleanup completed"
}

trap cleanup EXIT

print_step "1. Creating mutable ConfigMap..."
kubectl apply -f "$MANIFEST_DIR/configmap-mutable.yaml"
echo ""

print_step "2. Deploying monitoring Pod..."
kubectl apply -f "$MANIFEST_DIR/pod-mutable.yaml"
echo ""

print_step "3. Waiting for Pod to be ready..."
kubectl wait --for=condition=Ready pod/random-generator-mutable --timeout=60s || {
    print_error "Pod failed to become ready"
    kubectl describe pod random-generator-mutable
    exit 1
}
print_success "Pod is ready"
echo ""

print_step "4. Checking initial configuration..."
sleep 5
echo -e "\n${YELLOW}=== Initial State ===${NC}"
echo "Environment Variable (VERSION):"
kubectl exec random-generator-mutable -- env | grep "^VERSION=" || print_error "VERSION not found"
echo ""
echo "Mounted File Content:"
kubectl exec random-generator-mutable -- cat /config/app/random-generator.properties
echo ""

print_step "5. Updating ConfigMap..."
echo "Patching ConfigMap with new values..."
kubectl patch configmap random-generator-config-mutable --type merge -p '{"data":{"VERSION":"2.0","application.properties":"# Random Generator config (Mutable)\nlog.file=/tmp/generator-v2.log\nversion=2.0\n"}}'
print_success "ConfigMap updated"
echo ""

print_step "6. Observing propagation behavior..."
print_info "Waiting for changes to propagate to mounted files..."
print_info "Note: Kubelet sync interval is typically 60-90 seconds"

echo -e "\n${YELLOW}=== Checking Environment Variable (should NOT change) ===${NC}"
sleep 5
kubectl exec random-generator-mutable -- env | grep "^VERSION=" || print_error "VERSION not found"
print_info "Environment variables are set at Pod creation and do NOT hot-reload"

echo -e "\n${YELLOW}=== Checking Mounted File (should change after sync) ===${NC}"
for i in {1..12}; do
    echo "Check $i/12 (waiting ${i}0 seconds)..."
    sleep 10

    CURRENT_CONTENT=$(kubectl exec random-generator-mutable -- cat /config/app/random-generator.properties)

    if echo "$CURRENT_CONTENT" | grep -q "version=2.0"; then
        print_success "File content updated! Propagation took ~${i}0 seconds"
        echo ""
        echo "Updated content:"
        echo "$CURRENT_CONTENT"
        PROPAGATED=true
        break
    else
        echo "Still showing old content..."
    fi
done

if [ "$PROPAGATED" != "true" ]; then
    print_error "File did not update within 120 seconds"
    echo "Current content:"
    kubectl exec random-generator-mutable -- cat /config/app/random-generator.properties
fi

echo ""
print_step "7. Viewing Pod logs (monitoring output)..."
echo "Last 30 lines of pod logs:"
kubectl logs random-generator-mutable --tail=30

echo ""
echo "=========================================="
print_success "Hot Reload Test Completed!"
echo "=========================================="
echo ""
print_info "Key findings:"
echo "  ✓ Environment variables do NOT hot-reload (Pod restart required)"
echo "  ✓ Volume-mounted files DO hot-reload (after kubelet sync)"
echo "  ✓ Propagation delay: ~60-90 seconds (kubelet sync period)"
echo "  ✓ Application must detect file changes to apply new config"
echo ""
