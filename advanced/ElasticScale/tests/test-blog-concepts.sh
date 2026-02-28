#!/bin/bash

# Test 3: 블로그 핵심 개념 검증 테스트
# Chapter 29: Elastic Scale 블로그에서 다룬 핵심 개념들이 매니페스트에 반영되었는지 검증

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "Test 3: 블로그 핵심 개념 검증"
echo "========================================"

PASSED=0
FAILED=0

DEPLOYMENT="$MANIFEST_DIR/deployment.yml"
HPA="$MANIFEST_DIR/hpa.yml"
HPA_BEHAVIOR="$MANIFEST_DIR/hpa-with-behavior.yml"
VPA="$MANIFEST_DIR/vpa.yml"
STRESS_APP="$MANIFEST_DIR/stress-app.yml"

# === 개념 1: HPA 기본 동작 원리 ===
echo ""
echo -e "${BLUE}[개념 1] HPA 기본 동작 원리${NC}"
echo "  desiredReplicas = ceil[currentReplicas x (currentMetricValue / desiredMetricValue)]"
echo ""

echo "3.1.1 HPA 스케일링 공식의 기준 — averageUtilization 설정"
if grep -q 'averageUtilization:' "$HPA"; then
    UTIL=$(grep 'averageUtilization:' "$HPA" | awk '{print $2}')
    echo -e "${GREEN}[PASS]${NC} 목표 CPU 사용률 ${UTIL}% 설정 — 공식의 desiredMetricValue"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} averageUtilization 미설정"
    ((FAILED++))
fi

echo "3.1.2 HPA 동작 필수 조건 — Pod의 resource requests 정의"
if grep -q 'requests:' "$DEPLOYMENT" && grep -q 'cpu:' "$DEPLOYMENT"; then
    echo -e "${GREEN}[PASS]${NC} Deployment에 CPU requests 정의 — HPA 계산 기준점"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} CPU requests 미정의 — HPA 동작 불가"
    ((FAILED++))
fi

echo "3.1.3 HPA가 Deployment를 대상으로 설정 (ReplicaSet 아닌)"
if grep -A3 'scaleTargetRef:' "$HPA" | grep -q 'kind: Deployment'; then
    echo -e "${GREEN}[PASS]${NC} scaleTargetRef가 Deployment 대상 — 롤링 업데이트 시 HPA 유지"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} scaleTargetRef가 Deployment 아님"
    ((FAILED++))
fi

# === 개념 2: 메트릭 유형 ===
echo ""
echo -e "${BLUE}[개념 2] 메트릭 유형 — Resource / Object·Pod / External${NC}"
echo ""

echo "3.2.1 표준 메트릭 (Resource) 타입 사용"
if grep -q 'type: Resource' "$HPA"; then
    echo -e "${GREEN}[PASS]${NC} Resource 메트릭 타입 사용 (Metrics Server 제공)"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Resource 메트릭 타입 미사용"
    ((FAILED++))
fi

echo "3.2.2 CPU 메트릭 사용"
if grep -q 'name: cpu' "$HPA"; then
    echo -e "${GREEN}[PASS]${NC} CPU 리소스 메트릭 설정"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} CPU 메트릭 미설정"
    ((FAILED++))
fi

# === 개념 3: Behavior를 통한 스케일링 동작 세부 제어 ===
echo ""
echo -e "${BLUE}[개념 3] Behavior — 스케일링 동작 세부 제어${NC}"
echo ""

echo "3.3.1 scaleUp 정책 — 빠른 확장"
SCALEUP_WINDOW=$(grep -A2 'scaleUp:' "$HPA_BEHAVIOR" | grep 'stabilizationWindowSeconds:' | awk '{print $2}')
if [ "$SCALEUP_WINDOW" = "0" ]; then
    echo -e "${GREEN}[PASS]${NC} scaleUp stabilizationWindow=0 — 즉시 스케일업"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} scaleUp 즉시 반응 설정 아님 (현재: $SCALEUP_WINDOW)"
    ((FAILED++))
fi

echo "3.3.2 scaleDown 정책 — 보수적 축소 (Flapping 방지)"
SCALEDOWN_WINDOW=$(grep -A2 'scaleDown:' "$HPA_BEHAVIOR" | grep 'stabilizationWindowSeconds:' | awk '{print $2}')
if [ -n "$SCALEDOWN_WINDOW" ] && [ "$SCALEDOWN_WINDOW" -gt 0 ]; then
    echo -e "${GREEN}[PASS]${NC} scaleDown stabilizationWindow=${SCALEDOWN_WINDOW}s — 보수적 축소"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} scaleDown 안정화 기간 미설정"
    ((FAILED++))
fi

echo "3.3.3 비대칭 스케일링 패턴 (빠른 확장 + 느린 축소 = 프로덕션 권장)"
if [ "$SCALEUP_WINDOW" = "0" ] && [ -n "$SCALEDOWN_WINDOW" ] && [ "$SCALEDOWN_WINDOW" -gt 0 ]; then
    echo -e "${GREEN}[PASS]${NC} 비대칭 스케일링: 빠른 확장(0s) + 느린 축소(${SCALEDOWN_WINDOW}s)"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 비대칭 스케일링 패턴 미적용"
    ((FAILED++))
fi

echo "3.3.4 Percent 기반 스케일링 정책"
if grep -A5 'scaleDown:' "$HPA_BEHAVIOR" | grep -q 'type: Percent'; then
    echo -e "${GREEN}[PASS]${NC} Percent 기반 축소 — 대규모 배포에 유리"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Percent 기반 정책 없음"
    ((FAILED++))
fi

# === 개념 4: VPA (수직 스케일링) ===
echo ""
echo -e "${BLUE}[개념 4] VPA — 수직 스케일링${NC}"
echo ""

echo "3.4.1 VPA Off 모드 (추천만 제공, 적용 안 함)"
if grep -q '"Off"' "$VPA"; then
    echo -e "${GREEN}[PASS]${NC} updateMode=Off — 프로덕션 초기 도입 시 안전한 관찰 모드"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Off 모드 미설정"
    ((FAILED++))
fi

echo "3.4.2 VPA와 HPA 충돌 방지 — VPA는 Off 모드, HPA는 CPU 메트릭 사용"
HPA_USES_CPU=$(grep -c 'name: cpu' "$HPA" 2>/dev/null || echo "0")
VPA_IS_OFF=$(grep -c '"Off"' "$VPA" 2>/dev/null || echo "0")
if [ "$HPA_USES_CPU" -gt 0 ] && [ "$VPA_IS_OFF" -gt 0 ]; then
    echo -e "${GREEN}[PASS]${NC} VPA=Off + HPA=CPU — 이중 스케일링 충돌 방지"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} VPA/HPA 충돌 가능성 있음"
    ((FAILED++))
fi

echo "3.4.3 VPA resourcePolicy — 리소스 허용 범위 제한"
if grep -q 'containerPolicies:' "$VPA"; then
    echo -e "${GREEN}[PASS]${NC} containerPolicies로 컨테이너별 리소스 범위 제한"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} containerPolicies 미정의"
    ((FAILED++))
fi

# === 개념 5: 수동 vs 자동 스케일링 ===
echo ""
echo -e "${BLUE}[개념 5] 수동 vs 자동 스케일링${NC}"
echo ""

echo "3.5.1 선언형 스케일링 — Deployment에 replicas 정의"
if grep -q 'replicas:' "$DEPLOYMENT"; then
    REPLICAS=$(grep 'replicas:' "$DEPLOYMENT" | head -1 | awk '{print $2}')
    echo -e "${GREEN}[PASS]${NC} 선언형 레플리카 수: $REPLICAS (kubectl apply로 관리)"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} replicas 필드 미정의"
    ((FAILED++))
fi

echo "3.5.2 자동 스케일링 — HPA minReplicas < maxReplicas"
if grep -q 'minReplicas:' "$HPA" && grep -q 'maxReplicas:' "$HPA"; then
    MIN=$(grep 'minReplicas:' "$HPA" | awk '{print $2}')
    MAX=$(grep 'maxReplicas:' "$HPA" | awk '{print $2}')
    echo -e "${GREEN}[PASS]${NC} HPA 자동 범위: ${MIN} ~ ${MAX} — 부하에 따라 자동 조정"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} HPA 범위 설정 오류"
    ((FAILED++))
fi

# === 개념 6: 실습 구성 ===
echo ""
echo -e "${BLUE}[개념 6] 실습 구성 — Stress App으로 HPA 동작 확인${NC}"
echo ""

echo "3.6.1 부하 테스트용 Deployment 제공"
if grep -q 'kind: Deployment' "$STRESS_APP" && grep -q 'stress-app' "$STRESS_APP"; then
    echo -e "${GREEN}[PASS]${NC} stress-app Deployment 제공"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 부하 테스트 Deployment 없음"
    ((FAILED++))
fi

echo "3.6.2 부하 테스트용 Service 제공"
if grep -q 'kind: Service' "$STRESS_APP"; then
    echo -e "${GREEN}[PASS]${NC} stress-app Service 제공 (부하 생성기 접근용)"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 부하 테스트 Service 없음"
    ((FAILED++))
fi

echo "3.6.3 부하 테스트용 HPA 정의"
if grep -q 'kind: HorizontalPodAutoscaler' "$STRESS_APP"; then
    echo -e "${GREEN}[PASS]${NC} stress-app HPA 포함 — 올인원 배포 가능"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 부하 테스트 HPA 없음"
    ((FAILED++))
fi

echo "3.6.4 CPU limits 설정 — 부하 생성 시 CPU 경합 확인용"
if grep -A10 'name: stress' "$STRESS_APP" | grep -q 'limits:'; then
    echo -e "${GREEN}[PASS]${NC} CPU limits 설정 — 부하 제한 및 throttling 관찰 가능"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} CPU limits 미설정"
    ((FAILED++))
fi

echo ""
echo "========================================"
echo "결과: ${PASSED} 통과, ${FAILED} 실패"
echo "========================================"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
