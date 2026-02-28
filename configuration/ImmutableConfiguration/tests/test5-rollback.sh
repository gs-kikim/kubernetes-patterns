#!/bin/bash

# Test 5: Configuration Version Rollback Test
# This test verifies that configuration can be rolled back by changing the init container image

set -e

SCRIPT_DIR=$(dirname "$0")
source "$SCRIPT_DIR/common.sh"

print_header "Test 5: Configuration Version Rollback"

# Prerequisites check
check_kubectl
check_minikube

# Build both dev and prod config images
build_config_image "dev" "1.0"
build_config_image "prod" "1.0"

# Cleanup any existing resources
cleanup "deployment" "immutable-config-app"

# Initial deployment with dev config
print_header "Step 1: Deploy with Development Configuration"

print_info "Deploying application with development configuration..."
kubectl apply -f $SCRIPT_DIR/../manifests/01-basic-deployment.yaml

if ! wait_for_deployment "immutable-config-app" 120; then
    print_error "Initial deployment failed"
    exit 1
fi

POD_NAME=$(kubectl get pods -l app=immutable-config-demo -o jsonpath='{.items[0].metadata.name}')
print_info "Initial pod: $POD_NAME"

# Verify dev configuration
print_info "Verifying development configuration..."
DEV_LOGS=$(get_pod_logs $POD_NAME app)
assert_contains "$DEV_LOGS" "app.environment=development" "Development environment confirmed"
assert_contains "$DEV_LOGS" "log.level=DEBUG" "Development log level confirmed"

# Change to prod configuration
print_header "Step 2: Update to Production Configuration"

print_info "Updating init container image to production configuration..."
kubectl patch deployment immutable-config-app --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/initContainers/0/image", "value":"k8spatterns/immutable-config-prod:1.0"}]'

# Wait for rollout to complete
print_info "Waiting for rollout to complete..."
kubectl rollout status deployment/immutable-config-app --timeout=120s

# Wait for new pod to be fully ready
sleep 5

# Get new pod name by sorting by creation timestamp (newest first)
NEW_POD_NAME=$(kubectl get pods -l app=immutable-config-demo --field-selector=status.phase=Running --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}')
print_info "New pod after update: $NEW_POD_NAME"

# Verify new pod is different from old pod
if [ "$POD_NAME" == "$NEW_POD_NAME" ]; then
    print_error "Pod was not recreated after configuration change"
    TESTS_FAILED=$((TESTS_FAILED + 1))
else
    print_success "New pod created after configuration change"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# Verify prod configuration
print_info "Verifying production configuration..."
PROD_LOGS=$(get_pod_logs $NEW_POD_NAME app)
assert_contains "$PROD_LOGS" "app.environment=production" "Production environment confirmed"
assert_contains "$PROD_LOGS" "log.level=INFO" "Production log level confirmed"
assert_contains "$PROD_LOGS" "database.host=prod-db.cluster.local" "Production database confirmed"

# Rollback to dev configuration
print_header "Step 3: Rollback to Development Configuration"

print_info "Rolling back deployment..."
kubectl rollout undo deployment/immutable-config-app

# Wait for rollback to complete
print_info "Waiting for rollback to complete..."
kubectl rollout status deployment/immutable-config-app --timeout=120s

# Get pod name after rollback (newest Running pod)
sleep 5
ROLLBACK_POD_NAME=$(kubectl get pods -l app=immutable-config-demo --field-selector=status.phase=Running --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}')
print_info "Pod after rollback: $ROLLBACK_POD_NAME"

# Verify rollback to dev configuration
print_info "Verifying rollback to development configuration..."
ROLLBACK_LOGS=$(get_pod_logs $ROLLBACK_POD_NAME app)
assert_contains "$ROLLBACK_LOGS" "app.environment=development" "Development environment after rollback"
assert_contains "$ROLLBACK_LOGS" "log.level=DEBUG" "Development log level after rollback"

# Check rollout history
print_header "Deployment Rollout History"
kubectl rollout history deployment/immutable-config-app

# Verify multiple revisions exist
REVISION_COUNT=$(kubectl rollout history deployment/immutable-config-app | grep -E '^\s*[0-9]+\s+' | wc -l | tr -d ' ')
print_info "Total revisions: $REVISION_COUNT"

if [ $REVISION_COUNT -ge 2 ]; then
    print_success "Multiple revisions available for rollback ($REVISION_COUNT revisions)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_error "Expected at least 2 revisions, found $REVISION_COUNT"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Show current deployment image
print_info "Current init container image:"
kubectl get deployment immutable-config-app -o jsonpath='{.spec.template.spec.initContainers[0].image}'
echo ""

# Cleanup
print_info "Cleaning up resources..."
cleanup "deployment" "immutable-config-app"

# Print test summary
print_test_summary
