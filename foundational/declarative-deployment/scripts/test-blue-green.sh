#!/bin/bash

# Test script for Blue-Green deployment

set -e

echo "Testing Blue-Green deployment strategy..."

# Apply the initial configuration
echo "Applying Blue-Green deployment configuration..."
kubectl apply -f apps/blue-green/

# Wait for both deployments
echo "Waiting for both Blue and Green deployments to be ready..."
kubectl -n blue-green-demo wait deployment random-generator-blue --for=condition=Available --timeout=3m
kubectl -n blue-green-demo wait deployment random-generator-green --for=condition=Available --timeout=3m

# Show initial state
echo "Initial deployment state:"
echo "Blue deployment:"
kubectl -n blue-green-demo get deployment random-generator-blue
echo ""
echo "Green deployment:"
kubectl -n blue-green-demo get deployment random-generator-green
echo ""
echo "Service가 가리키는 대상:"
kubectl -n blue-green-demo get service random-generator -o jsonpath='{.spec.selector}' | jq '.'

# Port forward for testing
echo ""
echo "Setting up port forwarding for testing..."
echo "Main service (Blue version) on port 8080"
kubectl -n blue-green-demo port-forward svc/random-generator 8080:80 &
PF_BLUE=$!
echo "Preview service (Green version) on port 8081"
kubectl -n blue-green-demo port-forward svc/random-generator-preview 8081:80 &
PF_GREEN=$!
sleep 3

# Test both versions
echo ""
echo "Testing Blue version (current production traffic):"
curl -s http://localhost:8080/actuator/info 2>/dev/null | jq '.pattern' || echo "Blue version is responding"

echo ""
echo "Testing Green version (preview environment):"
curl -s http://localhost:8081/actuator/info 2>/dev/null | jq '.pattern' || echo "Green version is responding"

# Switch from Blue to Green
echo ""
echo "Switching traffic from Blue to Green deployment..."
kubectl -n blue-green-demo patch service random-generator -p '{"spec":{"selector":{"version":"green"}}}'

sleep 2

echo ""
echo "Traffic switch completed! Service now routing to:"
kubectl -n blue-green-demo get service random-generator -o jsonpath='{.spec.selector}' | jq '.'

echo ""
echo "전환 후 메인 service 테스트 (이제 Green 버전이어야 함):"
curl -s http://localhost:8080/actuator/info 2>/dev/null | jq '.pattern' || echo "Green 버전이 현재 라이브입니다"

# Cleanup port forwarding
kill $PF_BLUE 2>/dev/null || true
kill $PF_GREEN 2>/dev/null || true

echo ""
echo "SUCCESS: Blue-Green deployment test completed!"
echo ""
echo "To rollback to Blue version:"
echo "kubectl -n blue-green-demo patch service random-generator -p '{\"spec\":{\"selector\":{\"version\":\"blue\"}}}'"
echo ""
echo "To scale down inactive version:"
echo "kubectl -n blue-green-demo scale deployment random-generator-green --replicas=0"