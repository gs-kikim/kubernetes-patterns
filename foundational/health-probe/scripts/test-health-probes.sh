#!/bin/bash

# Health Probe Test Script
# This script tests various health probe scenarios in Kubernetes

set -e

NAMESPACE=${NAMESPACE:-health-probe-test}
MANIFEST_DIR="./manifests"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Wait for deployment to be ready
wait_for_deployment() {
    local deployment=$1
    local timeout=${2:-120}
    
    log_info "Waiting for deployment $deployment to be ready (timeout: ${timeout}s)..."
    
    if kubectl wait --for=condition=available --timeout=${timeout}s deployment/$deployment -n $NAMESPACE 2>/dev/null; then
        log_info "Deployment $deployment is ready"
        return 0
    else
        log_warn "Deployment $deployment did not become ready in time"
        return 1
    fi
}

# Test liveness probe scenarios
test_liveness_probes() {
    log_info "Testing Liveness Probes..."
    
    # Test HTTP liveness probe
    log_info "Deploying HTTP liveness probe test..."
    kubectl apply -f $MANIFEST_DIR/01-liveness-http.yaml -n $NAMESPACE
    wait_for_deployment "liveness-http-test" 60
    
    # Test TCP liveness probe
    log_info "Deploying TCP liveness probe test..."
    kubectl apply -f $MANIFEST_DIR/02-liveness-tcp.yaml -n $NAMESPACE
    wait_for_deployment "liveness-tcp-test" 60
    
    # Test Exec liveness probe
    log_info "Deploying Exec liveness probe test..."
    kubectl apply -f $MANIFEST_DIR/03-liveness-exec.yaml -n $NAMESPACE
    
    # Wait and check for restart
    log_info "Waiting 40 seconds to observe container restart due to failed liveness probe..."
    sleep 40
    
    RESTARTS=$(kubectl get pod -l app=liveness-exec-test -n $NAMESPACE -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}')
    if [ "$RESTARTS" -gt "0" ]; then
        log_info "Container restarted $RESTARTS times as expected"
    else
        log_warn "Container has not restarted yet"
    fi
}

# Test readiness probe scenarios
test_readiness_probes() {
    log_info "Testing Readiness Probes..."
    
    # Test Exec readiness probe
    log_info "Deploying Exec readiness probe test..."
    kubectl apply -f $MANIFEST_DIR/04-readiness-exec.yaml -n $NAMESPACE
    
    # Monitor endpoints
    log_info "Monitoring service endpoints..."
    for i in {1..6}; do
        READY_ENDPOINTS=$(kubectl get endpoints readiness-exec-test -n $NAMESPACE -o jsonpath='{.subsets[0].addresses}' 2>/dev/null | grep -o "ip" | wc -l)
        log_info "Ready endpoints: $READY_ENDPOINTS/3"
        sleep 5
    done
    
    # Test HTTP readiness probe
    log_info "Deploying HTTP readiness probe test..."
    kubectl apply -f $MANIFEST_DIR/05-readiness-http.yaml -n $NAMESPACE
    wait_for_deployment "readiness-http-test" 60
}

# Test startup probe
test_startup_probe() {
    log_info "Testing Startup Probe..."
    
    log_info "Deploying slow-starting application with startup probe..."
    kubectl apply -f $MANIFEST_DIR/06-startup-probe.yaml -n $NAMESPACE
    
    # Monitor pod status
    log_info "Monitoring pod startup (this will take ~90 seconds)..."
    START_TIME=$(date +%s)
    
    while true; do
        POD_STATUS=$(kubectl get pod -l app=startup-probe-test -n $NAMESPACE -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
        CONTAINER_READY=$(kubectl get pod -l app=startup-probe-test -n $NAMESPACE -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
        
        ELAPSED=$(($(date +%s) - START_TIME))
        
        if [ "$CONTAINER_READY" == "true" ]; then
            log_info "Container became ready after ${ELAPSED} seconds"
            break
        elif [ $ELAPSED -gt 150 ]; then
            log_warn "Startup probe test timed out after 150 seconds"
            break
        fi
        
        echo -n "."
        sleep 5
    done
    echo
}

# Test combined probes
test_combined_probes() {
    log_info "Testing Combined Probes..."
    
    kubectl apply -f $MANIFEST_DIR/07-combined-probes.yaml -n $NAMESPACE
    
    log_info "Monitoring all three probe types working together..."
    
    # Monitor for 60 seconds
    for i in {1..12}; do
        POD_NAME=$(kubectl get pod -l app=combined-probes-test -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        
        if [ ! -z "$POD_NAME" ]; then
            kubectl get pod $POD_NAME -n $NAMESPACE --no-headers | awk '{printf "Pod: %-30s Status: %-10s Ready: %-5s Restarts: %s\n", $1, $3, $2, $4}'
        fi
        
        sleep 5
    done
}

# Test readiness gate
test_readiness_gate() {
    log_info "Testing Custom Readiness Gate..."
    
    kubectl apply -f $MANIFEST_DIR/08-readiness-gate.yaml -n $NAMESPACE
    
    sleep 10
    
    POD_NAME=$(kubectl get pod -l app=readiness-gate-test -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ ! -z "$POD_NAME" ]; then
        log_info "Pod conditions:"
        kubectl get pod $POD_NAME -n $NAMESPACE -o json | jq '.status.conditions'
        
        # Simulate setting custom condition
        log_info "Setting custom readiness condition..."
        kubectl patch pod $POD_NAME -n $NAMESPACE --type='json' -p='[{"op": "add", "path": "/status/conditions/-", "value": {"type": "k8spatterns.io/load-balancer-ready", "status": "True", "lastTransitionTime": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}}]' 2>/dev/null || log_warn "Cannot patch pod status (requires appropriate RBAC permissions)"
    fi
}

# Monitor probe events
monitor_probe_events() {
    log_info "Monitoring probe-related events for 30 seconds..."
    
    kubectl get events -n $NAMESPACE --watch-only --field-selector reason=Unhealthy &
    EVENT_PID=$!
    
    sleep 30
    
    kill $EVENT_PID 2>/dev/null || true
}

# Cleanup
cleanup() {
    log_info "Cleaning up test resources..."
    
    for manifest in $MANIFEST_DIR/*.yaml; do
        kubectl delete -f $manifest -n $NAMESPACE --ignore-not-found=true
    done
    
    log_info "Cleanup completed"
}

# Main execution
main() {
    log_info "Starting Health Probe Tests"
    log_info "Namespace: $NAMESPACE"
    
    check_prerequisites
    
    # Run tests
    case "${1:-all}" in
        liveness)
            test_liveness_probes
            ;;
        readiness)
            test_readiness_probes
            ;;
        startup)
            test_startup_probe
            ;;
        combined)
            test_combined_probes
            ;;
        gate)
            test_readiness_gate
            ;;
        monitor)
            monitor_probe_events
            ;;
        cleanup)
            cleanup
            ;;
        all)
            test_liveness_probes
            echo
            test_readiness_probes
            echo
            test_startup_probe
            echo
            test_combined_probes
            echo
            test_readiness_gate
            echo
            monitor_probe_events
            ;;
        *)
            echo "Usage: $0 [liveness|readiness|startup|combined|gate|monitor|cleanup|all]"
            exit 1
            ;;
    esac
    
    log_info "Health Probe Tests completed"
}

# Handle script interruption
trap cleanup INT TERM

# Run main function
main "$@"