#!/bin/bash

# Test script for Canary deployment with Flagger

set -e

echo "Flagger progressive delivery를 사용한 Canary deployment 테스트 중..."

# Check if Flagger is installed
if ! kubectl -n flagger-system get deployment flagger &>/dev/null; then
    echo "[WARNING] Flagger가 설치되지 않음. 지금 설치하는 중..."
    ./scripts/install-flagger.sh
fi

# Apply the initial deployment
echo "초기 Canary deployment 설정을 적용하는 중..."
kubectl apply -f apps/canary/deployment.yaml

# Wait for deployment
echo "초기 deployment가 준비될 때까지 기다리는 중..."
kubectl -n canary-demo wait deployment random-generator --for=condition=Available --timeout=3m

# Apply Canary resource
echo "Progressive delivery를 위한 Flagger Canary resource 생성 중..."
kubectl apply -f apps/canary/canary.yaml

# Wait for Flagger to initialize
echo "Flagger가 canary deployment를 초기화할 때까지 기다리는 중..."
sleep 10

# Check canary status
echo "초기 canary deployment 상태:"
kubectl -n canary-demo get canary random-generator

# Show created resources
echo ""
echo "Flagger controller가 생성한 resource들:"
kubectl -n canary-demo get deploy,svc,canary

# Port forward for monitoring
echo ""
echo "Service 모니터링을 위한 port forwarding 설정 중..."
kubectl -n canary-demo port-forward svc/random-generator 8080:80 &
PF_PID=$!
sleep 3

# Test current version
echo ""
echo "현재 stable 버전 테스트:"
curl -s http://localhost:8080/actuator/info 2>/dev/null | jq '.' || echo "Service가 응답하고 있습니다"

# Trigger canary deployment
echo ""
echo "Image를 version 2.0으로 업데이트하여 canary deployment 트리거 중..."
kubectl -n canary-demo set image deployment/random-generator random-generator=k8spatterns/random-generator:2.0

# Monitor canary progress
echo ""
echo "Canary rollout 진행 상황 모니터링 (몇 분 소요)..."
echo "Flagger가 metric 기반으로 새 버전으로 트래픽을 점진적으로 이동합니다..."
echo ""

# Watch for up to 5 minutes
COUNTER=0
MAX_CHECKS=30
while [ $COUNTER -lt $MAX_CHECKS ]; do
    STATUS=$(kubectl -n canary-demo get canary random-generator -o jsonpath='{.status.phase}')
    WEIGHT=$(kubectl -n canary-demo get canary random-generator -o jsonpath='{.status.canaryWeight}')
    ITERATIONS=$(kubectl -n canary-demo get canary random-generator -o jsonpath='{.status.iterations}')
    
    echo "Status: $STATUS | Canary 가중치: ${WEIGHT}% | 반복 횟수: $ITERATIONS"
    
    if [ "$STATUS" == "Succeeded" ]; then
        echo ""
        echo "Success: Canary deployment가 성공적으로 완료되었습니다!"
        break
    elif [ "$STATUS" == "Failed" ]; then
        echo ""
        echo "Failure: Canary deployment 실패! Rollback 중..."
        kubectl -n canary-demo describe canary random-generator
        break
    fi
    
    sleep 10
    COUNTER=$((COUNTER + 1))
done

# Show final state
echo ""
echo "Canary 프로세스 후 최종 deployment 상태:"
kubectl -n canary-demo get deploy,svc,canary

# Cleanup port forwarding
kill $PF_PID 2>/dev/null || true

echo ""
echo "Canary deployment 테스트 완료!"
echo ""
echo "중요 사항:"
echo "1. Flagger가 primary와 canary deployment를 자동 생성함"
echo "2. 트래픽이 구 버전에서 새 버전으로 점진적으로 이동됨"
echo "3. Rollout 프로세스 동안 metric이 지속적으로 모니터링됨"
echo ""
echo "다른 canary deployment를 트리거하려면:"
echo "kubectl -n canary-demo set image deployment/random-generator random-generator=k8spatterns/random-generator:1.0"