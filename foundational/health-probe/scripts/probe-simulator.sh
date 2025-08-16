#!/bin/bash

# Probe Failure Simulator
# This script simulates various probe failure scenarios for testing

set -e

NAMESPACE=${NAMESPACE:-health-probe-test}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_action() {
    echo -e "${BLUE}[ACTION]${NC} $1"
}

# Simulate liveness probe failure
simulate_liveness_failure() {
    local deployment=$1
    local pod_name=$(kubectl get pod -l app=$deployment -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$pod_name" ]; then
        log_error "No pod found for deployment $deployment"
        return 1
    fi
    
    log_action "Simulating liveness probe failure for pod $pod_name"
    
    # If the app has a toggle endpoint, use it
    if kubectl exec -n $NAMESPACE $pod_name -- curl -s -X POST http://localhost:8080/toggle-health &>/dev/null; then
        log_info "Toggled health status via API"
    else
        # Otherwise, try to kill the health check process or corrupt the health file
        kubectl exec -n $NAMESPACE $pod_name -- sh -c "rm -f /tmp/healthy 2>/dev/null || pkill -f health 2>/dev/null || true"
        log_info "Removed health indicator"
    fi
    
    # Monitor restart
    log_info "Monitoring pod for restart..."
    local initial_restarts=$(kubectl get pod $pod_name -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].restartCount}')
    
    for i in {1..60}; do
        current_restarts=$(kubectl get pod $pod_name -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")
        if [ "$current_restarts" -gt "$initial_restarts" ]; then
            log_info "Pod restarted! (Restarts: $initial_restarts -> $current_restarts)"
            return 0
        fi
        sleep 2
        echo -n "."
    done
    echo
    log_warn "Pod did not restart within timeout period"
}

# Simulate readiness probe failure
simulate_readiness_failure() {
    local deployment=$1
    local service=${2:-$deployment}
    
    log_action "Simulating readiness probe failure for deployment $deployment"
    
    # Get all pods for the deployment
    local pods=$(kubectl get pod -l app=$deployment -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$pods" ]; then
        log_error "No pods found for deployment $deployment"
        return 1
    fi
    
    # Check initial endpoints
    local initial_endpoints=$(kubectl get endpoints $service -n $NAMESPACE -o jsonpath='{.subsets[0].addresses}' 2>/dev/null | grep -o "ip" | wc -l)
    log_info "Initial ready endpoints: $initial_endpoints"
    
    # Make first pod unready
    local first_pod=$(echo $pods | cut -d' ' -f1)
    log_info "Making pod $first_pod unready..."
    
    # Remove readiness indicator
    kubectl exec -n $NAMESPACE $first_pod -- sh -c "rm -f /tmp/random-generator-ready 2>/dev/null || curl -X POST http://localhost:8080/toggle-ready 2>/dev/null || true"
    
    # Monitor endpoints
    log_info "Monitoring service endpoints..."
    for i in {1..30}; do
        current_endpoints=$(kubectl get endpoints $service -n $NAMESPACE -o jsonpath='{.subsets[0].addresses}' 2>/dev/null | grep -o "ip" | wc -l)
        if [ "$current_endpoints" -lt "$initial_endpoints" ]; then
            log_info "Endpoint removed from service! (Endpoints: $initial_endpoints -> $current_endpoints)"
            
            # Restore readiness after 10 seconds
            sleep 10
            log_info "Restoring readiness..."
            kubectl exec -n $NAMESPACE $first_pod -- sh -c "touch /tmp/random-generator-ready 2>/dev/null || curl -X POST http://localhost:8080/toggle-ready 2>/dev/null || true"
            return 0
        fi
        sleep 1
        echo -n "."
    done
    echo
    log_warn "Endpoint was not removed within timeout period"
}

# Simulate slow startup
simulate_slow_startup() {
    local deployment=$1
    
    log_action "Simulating slow startup scenario for deployment $deployment"
    
    # Delete existing pods to force restart
    kubectl delete pod -l app=$deployment -n $NAMESPACE --force --grace-period=0
    
    log_info "Pod deleted, monitoring startup progress..."
    
    local start_time=$(date +%s)
    
    while true; do
        local pod_name=$(kubectl get pod -l app=$deployment -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        
        if [ ! -z "$pod_name" ]; then
            local container_ready=$(kubectl get pod $pod_name -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
            local phase=$(kubectl get pod $pod_name -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null)
            
            local elapsed=$(($(date +%s) - start_time))
            
            echo -e "\rElapsed: ${elapsed}s | Phase: $phase | Ready: $container_ready"
            
            if [ "$container_ready" == "true" ]; then
                echo
                log_info "Container became ready after ${elapsed} seconds"
                break
            elif [ $elapsed -gt 180 ]; then
                echo
                log_error "Startup timed out after 180 seconds"
                break
            fi
        fi
        
        sleep 2
    done
}

# Monitor probe metrics
monitor_probe_metrics() {
    local duration=${1:-60}
    
    log_info "Monitoring probe metrics for ${duration} seconds..."
    
    end_time=$(($(date +%s) + duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        clear
        echo -e "${GREEN}=== Health Probe Status Dashboard ===${NC}"
        echo -e "Time: $(date '+%Y-%m-%d %H:%M:%S')"
        echo
        
        kubectl get pod -n $NAMESPACE -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
READY:.status.containerStatuses[0].ready,\
RESTARTS:.status.containerStatuses[0].restartCount,\
STARTED:.status.containerStatuses[0].started,\
AGE:.metadata.creationTimestamp
        
        echo
        echo -e "${YELLOW}Recent Events:${NC}"
        kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | grep -E "(Liveness|Readiness|Startup|probe)" | tail -5
        
        remaining=$((end_time - $(date +%s)))
        echo
        echo -e "${BLUE}Monitoring for $remaining more seconds... (Ctrl+C to stop)${NC}"
        
        sleep 5
    done
}

# Chaos testing - random probe failures
chaos_test() {
    local duration=${1:-300}
    local interval=${2:-30}
    
    log_warn "Starting chaos testing for ${duration} seconds"
    log_warn "Random probe failures will be induced every ${interval} seconds"
    
    local end_time=$(($(date +%s) + duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        # Pick a random deployment
        local deployments=$(kubectl get deployment -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')
        local deployment_array=($deployments)
        
        if [ ${#deployment_array[@]} -eq 0 ]; then
            log_error "No deployments found"
            break
        fi
        
        local random_deployment=${deployment_array[$RANDOM % ${#deployment_array[@]}]}
        
        # Pick a random failure type
        local failure_types=("liveness" "readiness" "slow")
        local random_failure=${failure_types[$RANDOM % ${#failure_types[@]}]}
        
        log_action "Inducing $random_failure failure on $random_deployment"
        
        case $random_failure in
            liveness)
                simulate_liveness_failure $random_deployment
                ;;
            readiness)
                simulate_readiness_failure $random_deployment
                ;;
            slow)
                simulate_slow_startup $random_deployment
                ;;
        esac
        
        local remaining=$((end_time - $(date +%s)))
        if [ $remaining -gt $interval ]; then
            log_info "Waiting ${interval} seconds before next failure..."
            sleep $interval
        fi
    done
    
    log_info "Chaos testing completed"
}

# Main menu
show_menu() {
    echo -e "${GREEN}=== Probe Failure Simulator ===${NC}"
    echo "1. Simulate Liveness Probe Failure"
    echo "2. Simulate Readiness Probe Failure"
    echo "3. Simulate Slow Startup"
    echo "4. Monitor Probe Metrics"
    echo "5. Start Chaos Testing"
    echo "6. Exit"
    echo
}

# Main execution
main() {
    while true; do
        show_menu
        read -p "Select option: " option
        
        case $option in
            1)
                read -p "Enter deployment name: " deployment
                simulate_liveness_failure $deployment
                ;;
            2)
                read -p "Enter deployment name: " deployment
                read -p "Enter service name (or press Enter to use deployment name): " service
                simulate_readiness_failure $deployment ${service:-$deployment}
                ;;
            3)
                read -p "Enter deployment name: " deployment
                simulate_slow_startup $deployment
                ;;
            4)
                read -p "Monitor duration in seconds (default 60): " duration
                monitor_probe_metrics ${duration:-60}
                ;;
            5)
                read -p "Test duration in seconds (default 300): " duration
                read -p "Failure interval in seconds (default 30): " interval
                chaos_test ${duration:-300} ${interval:-30}
                ;;
            6)
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid option"
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Run main function
main