#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

echo "=========================================="
echo "Configuration Resource - Immutable Test"
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
    kubectl delete configmap random-generator-config-immutable --ignore-not-found=true 2>/dev/null || true
    print_info "Cleanup completed"
}

trap cleanup EXIT

print_step "1. Creating immutable ConfigMap..."
kubectl apply -f "$MANIFEST_DIR/configmap-immutable.yaml"
echo ""

print_info "Checking immutable field:"
kubectl get configmap random-generator-config-immutable -o jsonpath='{.immutable}'
echo ""
echo ""

print_step "2. Verifying immutable ConfigMap content..."
kubectl get configmap random-generator-config-immutable -o yaml | grep -A 10 "^data:"
echo ""

print_step "3. Attempting to update immutable ConfigMap..."
echo "Trying to patch PATTERN field..."

if kubectl patch configmap random-generator-config-immutable --type merge -p '{"data":{"PATTERN":"Modified Value"}}' 2>&1 | grep -q "Forbidden"; then
    print_success "Update correctly rejected! ConfigMap is truly immutable"
    echo ""
    kubectl patch configmap random-generator-config-immutable --type merge -p '{"data":{"PATTERN":"Modified Value"}}' 2>&1 || true
else
    print_error "Update was allowed! This should not happen with immutable ConfigMaps"
fi

echo ""

print_step "4. Attempting to add new key to immutable ConfigMap..."
echo "Trying to add NEW_KEY field..."

if kubectl patch configmap random-generator-config-immutable --type merge -p '{"data":{"NEW_KEY":"New Value"}}' 2>&1 | grep -q "Forbidden"; then
    print_success "Adding new key correctly rejected!"
    echo ""
    kubectl patch configmap random-generator-config-immutable --type merge -p '{"data":{"NEW_KEY":"New Value"}}' 2>&1 || true
else
    print_error "Adding new key was allowed! This should not happen"
fi

echo ""

print_step "5. Comparing mutable vs immutable ConfigMaps..."

echo -e "\n${YELLOW}=== Creating mutable ConfigMap for comparison ===${NC}"
kubectl apply -f "$MANIFEST_DIR/configmap-mutable.yaml"
echo ""

echo "Attempting to update mutable ConfigMap..."
kubectl patch configmap random-generator-config-mutable --type merge -p '{"data":{"PATTERN":"Modified Value - This Should Work"}}'
print_success "Mutable ConfigMap updated successfully"
echo ""

echo "Verifying update:"
kubectl get configmap random-generator-config-mutable -o jsonpath='{.data.PATTERN}'
echo ""
echo ""

print_step "6. Benefits of immutable ConfigMaps..."
echo ""
print_info "Immutable ConfigMaps provide:"
echo "  1. Protection against accidental updates"
echo "  2. Safer rollouts (no configuration drift)"
echo "  3. Better performance (kubelet doesn't need to watch for changes)"
echo "  4. Improved cluster performance at scale"
echo ""

print_step "7. How to update immutable ConfigMaps..."
print_info "To update an immutable ConfigMap, you must:"
echo "  1. Create a new ConfigMap with a different name (e.g., app-config-v2)"
echo "  2. Update Deployment/Pod to reference the new ConfigMap"
echo "  3. Delete the old ConfigMap after rollout"
echo ""

echo "Example with versioned names:"
cat <<'EOF'
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-v1
data:
  VERSION: "1.0"
immutable: true
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-v2
data:
  VERSION: "2.0"
immutable: true
---
# Update Deployment to use app-config-v2
EOF

echo ""
echo "=========================================="
print_success "Immutable ConfigMap Test Completed!"
echo "=========================================="
echo ""
print_info "Key findings:"
echo "  ✓ Immutable ConfigMaps cannot be modified after creation"
echo "  ✓ Updates must be done by creating new ConfigMaps"
echo "  ✓ Provides protection against configuration drift"
echo "  ✓ Improves cluster performance (no watch overhead)"
echo ""

# Cleanup mutable configmap
kubectl delete configmap random-generator-config-mutable --ignore-not-found=true 2>/dev/null || true
