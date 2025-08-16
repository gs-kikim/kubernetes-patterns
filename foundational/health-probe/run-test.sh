#!/bin/bash

# Simple test runner for Minikube environment
set -e

echo "🚀 Starting Health Probe Tests on Minikube"
echo "==========================================="

# Check Minikube status
echo "📌 Checking Minikube status..."
minikube status || { echo "Minikube is not running. Please start it first."; exit 1; }

# Set namespace
NAMESPACE="health-probe-test"
echo "📌 Using namespace: $NAMESPACE"

# Clean up previous resources
echo "🧹 Cleaning up previous test resources..."
kubectl delete all --all -n $NAMESPACE --force --grace-period=0 2>/dev/null || true

echo ""
echo "===== TEST 1: Liveness Probes ====="
echo ""

# Test 1: HTTP Liveness
echo "1️⃣ Testing HTTP Liveness Probe..."
kubectl apply -f manifests/01-liveness-http.yaml -n $NAMESPACE
sleep 5
kubectl get pods -l app=liveness-http-test -n $NAMESPACE

# Test 2: TCP Liveness  
echo ""
echo "2️⃣ Testing TCP Liveness Probe..."
kubectl apply -f manifests/02-liveness-tcp.yaml -n $NAMESPACE
sleep 5
kubectl get pods -l app=liveness-tcp-test -n $NAMESPACE

# Test 3: Exec Liveness
echo ""
echo "3️⃣ Testing Exec Liveness Probe (will restart after 30s)..."
kubectl apply -f manifests/03-liveness-exec.yaml -n $NAMESPACE
echo "Waiting for initial start..."
sleep 10
kubectl get pods -l app=liveness-exec-test -n $NAMESPACE
echo "Waiting 40 seconds for container restart..."
sleep 40
echo "After restart:"
kubectl get pods -l app=liveness-exec-test -n $NAMESPACE

echo ""
echo "===== TEST 2: Readiness Probes ====="
echo ""

# Test 4: Exec Readiness
echo "4️⃣ Testing Exec Readiness Probe..."
kubectl apply -f manifests/04-readiness-exec.yaml -n $NAMESPACE
echo "Monitoring endpoints (30 seconds)..."
for i in {1..6}; do
    READY=$(kubectl get endpoints readiness-exec-test -n $NAMESPACE -o jsonpath='{.subsets[0].addresses}' 2>/dev/null | grep -o "ip" | wc -l || echo "0")
    echo "  Ready endpoints: $READY/3"
    sleep 5
done

# Test 5: HTTP Readiness
echo ""
echo "5️⃣ Testing HTTP Readiness Probe..."
kubectl apply -f manifests/05-readiness-http.yaml -n $NAMESPACE
sleep 10
kubectl get pods -l app=readiness-http-test -n $NAMESPACE

echo ""
echo "===== TEST 3: Startup Probe ====="
echo ""

# Test 6: Startup Probe
echo "6️⃣ Testing Startup Probe (slow start - 90s)..."
kubectl apply -f manifests/06-startup-probe.yaml -n $NAMESPACE
echo "Monitoring startup progress..."
START=$(date +%s)
while true; do
    POD_STATUS=$(kubectl get pod -l app=startup-probe-test -n $NAMESPACE -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Pending")
    READY=$(kubectl get pod -l app=startup-probe-test -n $NAMESPACE -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
    ELAPSED=$(($(date +%s) - START))
    
    echo "  Time: ${ELAPSED}s | Status: $POD_STATUS | Ready: $READY"
    
    if [ "$READY" == "true" ]; then
        echo "✅ Container ready after ${ELAPSED} seconds"
        break
    elif [ $ELAPSED -gt 150 ]; then
        echo "⚠️ Timeout after 150 seconds"
        break
    fi
    sleep 10
done

echo ""
echo "===== TEST 4: Combined Probes ====="
echo ""

# Test 7: Combined Probes
echo "7️⃣ Testing Combined Probes (all three types)..."
kubectl apply -f manifests/07-combined-probes.yaml -n $NAMESPACE
echo "Monitoring combined probe behavior..."
for i in {1..6}; do
    kubectl get pods -l app=combined-probes-test -n $NAMESPACE --no-headers 2>/dev/null || echo "Waiting for pods..."
    sleep 10
done

echo ""
echo "===== FINAL STATUS ====="
echo ""
echo "📊 All Pods Status:"
kubectl get pods -n $NAMESPACE -o wide

echo ""
echo "📊 Services & Endpoints:"
kubectl get svc,endpoints -n $NAMESPACE

echo ""
echo "📊 Recent Events:"
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | grep -E "(probe|Liveness|Readiness|Startup|Unhealthy)" | tail -10 || echo "No probe-related events"

echo ""
echo "✅ Test execution completed!"
echo "To clean up: kubectl delete all --all -n $NAMESPACE"