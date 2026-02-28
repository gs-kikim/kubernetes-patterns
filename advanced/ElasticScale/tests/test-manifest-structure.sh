#!/bin/bash

# Test 2: Kubernetes 매니페스트 구조 검증 테스트
# Elastic Scale 패턴의 매니페스트가 올바른 구조를 갖추고 있는지 검증

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "Test 2: 매니페스트 구조 검증"
echo "========================================"

PASSED=0
FAILED=0

DEPLOYMENT="$MANIFEST_DIR/deployment.yml"
HPA="$MANIFEST_DIR/hpa.yml"
HPA_BEHAVIOR="$MANIFEST_DIR/hpa-with-behavior.yml"
VPA="$MANIFEST_DIR/vpa.yml"
STRESS_APP="$MANIFEST_DIR/stress-app.yml"

# === Deployment 구조 검증 ===
echo ""
echo "--- Deployment 구조 검증 ---"

echo ""
echo "2.1 Deployment 리소스 정의 확인"
if grep -q 'kind: Deployment' "$DEPLOYMENT"; then
    echo -e "${GREEN}[PASS]${NC} Deployment 리소스 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Deployment 리소스 정의 없음"
    ((FAILED++))
fi

echo ""
echo "2.2 Service 리소스 정의 확인"
if grep -q 'kind: Service' "$DEPLOYMENT"; then
    echo -e "${GREEN}[PASS]${NC} Service 리소스 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Service 리소스 정의 없음"
    ((FAILED++))
fi

echo ""
echo "2.3 CPU requests 정의 확인 (HPA 동작 필수 조건)"
if grep -q 'cpu:' "$DEPLOYMENT" && grep -q 'requests:' "$DEPLOYMENT"; then
    echo -e "${GREEN}[PASS]${NC} CPU requests 정의됨 — HPA 동작 가능"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} CPU requests 미정의 — HPA 동작 불가"
    ((FAILED++))
fi

echo ""
echo "2.4 Memory requests 정의 확인"
if grep -q 'memory:' "$DEPLOYMENT"; then
    echo -e "${GREEN}[PASS]${NC} Memory requests 정의됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Memory requests 미정의"
    ((FAILED++))
fi

echo ""
echo "2.5 containerPort 정의 확인"
if grep -q 'containerPort:' "$DEPLOYMENT"; then
    echo -e "${GREEN}[PASS]${NC} containerPort 정의됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} containerPort 미정의"
    ((FAILED++))
fi

echo ""
echo "2.6 Label selector 일치 확인 (Deployment ↔ Service)"
if grep -q 'app: random-generator' "$DEPLOYMENT"; then
    echo -e "${GREEN}[PASS]${NC} app: random-generator label 정의됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Label 불일치"
    ((FAILED++))
fi

# === HPA 구조 검증 ===
echo ""
echo "--- HPA 구조 검증 ---"

echo ""
echo "2.7 HPA API 버전 확인 (autoscaling/v2)"
if grep -q 'autoscaling/v2' "$HPA"; then
    echo -e "${GREEN}[PASS]${NC} autoscaling/v2 API 사용"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 올바른 API 버전 아님"
    ((FAILED++))
fi

echo ""
echo "2.8 scaleTargetRef 확인 (Deployment 참조)"
if grep -q 'kind: Deployment' "$HPA" && grep -q 'name: random-generator' "$HPA"; then
    echo -e "${GREEN}[PASS]${NC} scaleTargetRef가 random-generator Deployment 참조"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} scaleTargetRef 설정 오류"
    ((FAILED++))
fi

echo ""
echo "2.9 minReplicas / maxReplicas 범위 확인"
if grep -q 'minReplicas:' "$HPA" && grep -q 'maxReplicas:' "$HPA"; then
    MIN=$(grep 'minReplicas:' "$HPA" | awk '{print $2}')
    MAX=$(grep 'maxReplicas:' "$HPA" | awk '{print $2}')
    if [ "$MIN" -lt "$MAX" ]; then
        echo -e "${GREEN}[PASS]${NC} 레플리카 범위: $MIN ~ $MAX"
        ((PASSED++))
    else
        echo -e "${RED}[FAIL]${NC} minReplicas($MIN) >= maxReplicas($MAX)"
        ((FAILED++))
    fi
else
    echo -e "${RED}[FAIL]${NC} minReplicas/maxReplicas 미정의"
    ((FAILED++))
fi

echo ""
echo "2.10 CPU Utilization 메트릭 타입 확인"
if grep -q 'type: Resource' "$HPA" && grep -q 'type: Utilization' "$HPA"; then
    echo -e "${GREEN}[PASS]${NC} Resource/Utilization 메트릭 사용"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 메트릭 타입 설정 오류"
    ((FAILED++))
fi

echo ""
echo "2.11 averageUtilization 값 확인"
if grep -q 'averageUtilization:' "$HPA"; then
    UTIL=$(grep 'averageUtilization:' "$HPA" | awk '{print $2}')
    echo -e "${GREEN}[PASS]${NC} averageUtilization: ${UTIL}% 설정"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} averageUtilization 미설정"
    ((FAILED++))
fi

# === HPA Behavior 구조 검증 ===
echo ""
echo "--- HPA Behavior 구조 검증 ---"

echo ""
echo "2.12 behavior 필드 정의 확인"
if grep -q 'behavior:' "$HPA_BEHAVIOR"; then
    echo -e "${GREEN}[PASS]${NC} behavior 필드 정의됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} behavior 필드 없음"
    ((FAILED++))
fi

echo ""
echo "2.13 scaleUp 정책 확인"
if grep -q 'scaleUp:' "$HPA_BEHAVIOR"; then
    echo -e "${GREEN}[PASS]${NC} scaleUp 정책 정의됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} scaleUp 정책 없음"
    ((FAILED++))
fi

echo ""
echo "2.14 scaleDown 정책 확인"
if grep -q 'scaleDown:' "$HPA_BEHAVIOR"; then
    echo -e "${GREEN}[PASS]${NC} scaleDown 정책 정의됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} scaleDown 정책 없음"
    ((FAILED++))
fi

echo ""
echo "2.15 stabilizationWindowSeconds 확인"
if grep -q 'stabilizationWindowSeconds:' "$HPA_BEHAVIOR"; then
    echo -e "${GREEN}[PASS]${NC} stabilizationWindowSeconds 설정됨 (Flapping 방지)"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} stabilizationWindowSeconds 미설정"
    ((FAILED++))
fi

echo ""
echo "2.16 스케일링 정책 타입 확인 (Percent/Pods)"
if grep -q 'type: Percent' "$HPA_BEHAVIOR"; then
    echo -e "${GREEN}[PASS]${NC} Percent 기반 스케일링 정책 정의됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 스케일링 정책 타입 미정의"
    ((FAILED++))
fi

# === VPA 구조 검증 ===
echo ""
echo "--- VPA 구조 검증 ---"

echo ""
echo "2.17 VPA 리소스 정의 확인"
if grep -q 'kind: VerticalPodAutoscaler' "$VPA"; then
    echo -e "${GREEN}[PASS]${NC} VerticalPodAutoscaler 리소스 정의됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} VerticalPodAutoscaler 리소스 없음"
    ((FAILED++))
fi

echo ""
echo "2.18 VPA updateMode 확인"
if grep -q 'updateMode:' "$VPA"; then
    MODE=$(grep 'updateMode:' "$VPA" | awk '{print $2}' | tr -d '"')
    echo -e "${GREEN}[PASS]${NC} VPA updateMode: $MODE"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} VPA updateMode 미설정"
    ((FAILED++))
fi

echo ""
echo "2.19 VPA resourcePolicy 확인 (minAllowed/maxAllowed)"
if grep -q 'minAllowed:' "$VPA" && grep -q 'maxAllowed:' "$VPA"; then
    echo -e "${GREEN}[PASS]${NC} VPA 리소스 범위(minAllowed/maxAllowed) 정의됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} VPA 리소스 범위 미정의"
    ((FAILED++))
fi

echo ""
echo "2.20 VPA targetRef 확인"
if grep -q 'kind: Deployment' "$VPA" && grep -q 'name: random-generator' "$VPA"; then
    echo -e "${GREEN}[PASS]${NC} VPA targetRef가 random-generator Deployment 참조"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} VPA targetRef 설정 오류"
    ((FAILED++))
fi

# === Stress App 구조 검증 ===
echo ""
echo "--- Stress App (HPA 실습용) 구조 검증 ---"

echo ""
echo "2.21 stress-app Deployment + Service + HPA 정의 확인"
STRESS_KINDS=$(grep 'kind:' "$STRESS_APP" | awk '{print $2}' | sort | tr '\n' ',')
if echo "$STRESS_KINDS" | grep -q 'Deployment' && \
   echo "$STRESS_KINDS" | grep -q 'Service' && \
   echo "$STRESS_KINDS" | grep -q 'HorizontalPodAutoscaler'; then
    echo -e "${GREEN}[PASS]${NC} Deployment, Service, HPA 모두 정의됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 필수 리소스 누락: $STRESS_KINDS"
    ((FAILED++))
fi

echo ""
echo "2.22 stress-app CPU requests 정의 확인"
if grep -q 'cpu:' "$STRESS_APP" && grep -q 'requests:' "$STRESS_APP"; then
    echo -e "${GREEN}[PASS]${NC} stress-app CPU requests 정의됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} stress-app CPU requests 미정의"
    ((FAILED++))
fi

echo ""
echo "========================================"
echo "결과: ${PASSED} 통과, ${FAILED} 실패"
echo "========================================"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
