#!/bin/bash

# Test 4: 블로그 핵심 개념 검증 테스트
# 블로그에서 다룬 Controller 패턴의 핵심 개념들이 매니페스트에 반영되었는지 검증

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "Test 4: 블로그 핵심 개념 검증"
echo "========================================"

PASSED=0
FAILED=0

CONTROLLER_SCRIPT="$MANIFEST_DIR/config-watcher-controller.sh"
CONTROLLER_MANIFEST="$MANIFEST_DIR/config-watcher-controller.yml"
WEBAPP_MANIFEST="$MANIFEST_DIR/web-app.yml"

# 4.1 Observe-Analyze-Act 사이클 구현 확인
echo ""
echo -e "${BLUE}[개념 1] Observe-Analyze-Act 사이클${NC}"
echo ""

# Observe: watch=true로 이벤트 감시
echo "4.1.1 Observe - 이벤트 감시 (watch=true)"
if grep -q 'watch=true' "$CONTROLLER_SCRIPT"; then
    echo -e "${GREEN}[PASS]${NC} Observe 단계: ConfigMap 변경 이벤트 감시"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Observe 단계 구현 없음"
    ((FAILED++))
fi

# Analyze: 이벤트 타입과 Annotation 분석
echo "4.1.2 Analyze - 이벤트 분석"
if grep -q 'type = "MODIFIED"' "$CONTROLLER_SCRIPT" && grep -q 'pod_selector' "$CONTROLLER_SCRIPT"; then
    echo -e "${GREEN}[PASS]${NC} Analyze 단계: 이벤트 타입/Annotation 분석"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Analyze 단계 구현 없음"
    ((FAILED++))
fi

# Act: Pod 삭제 작업 수행
echo "4.1.3 Act - 조정 작업 수행"
if grep -q 'DELETE' "$CONTROLLER_SCRIPT"; then
    echo -e "${GREEN}[PASS]${NC} Act 단계: Pod 삭제 작업 수행"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Act 단계 구현 없음"
    ((FAILED++))
fi

# 4.2 Ambassador 패턴 (Chapter 18)
echo ""
echo -e "${BLUE}[개념 2] Ambassador 패턴 (kubeapi-proxy)${NC}"
echo ""

echo "4.2.1 Ambassador 컨테이너 존재"
if grep -q 'kubeapi-proxy' "$CONTROLLER_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} Ambassador 컨테이너(kubeapi-proxy) 정의"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Ambassador 컨테이너 없음"
    ((FAILED++))
fi

echo "4.2.2 localhost:8001 프록시 사용"
if grep -q 'localhost:8001' "$CONTROLLER_SCRIPT"; then
    echo -e "${GREEN}[PASS]${NC} localhost:8001 통해 API Server 접근"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 프록시 설정 없음"
    ((FAILED++))
fi

# 4.3 Self Awareness 패턴 (Chapter 14) - Downward API
echo ""
echo -e "${BLUE}[개념 3] Self Awareness 패턴 - Downward API${NC}"
echo ""

echo "4.3.1 metadata.namespace 참조"
if grep -q 'metadata.namespace' "$CONTROLLER_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} Downward API로 현재 네임스페이스 주입"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Downward API 사용 안함"
    ((FAILED++))
fi

# 4.4 Singleton Service 패턴 (Chapter 10)
echo ""
echo -e "${BLUE}[개념 4] Singleton Service 패턴${NC}"
echo ""

echo "4.4.1 단일 레플리카 설정"
if grep -q 'replicas: 1' "$CONTROLLER_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} Singleton 패턴: replicas=1로 동시성 방지"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Singleton 패턴 미적용"
    ((FAILED++))
fi

# 4.5 Controller 데이터 저장 위치 - Annotations
echo ""
echo -e "${BLUE}[개념 5] Controller 데이터 저장 - Annotations 사용${NC}"
echo ""

echo "4.5.1 Annotation 기반 설정"
if grep -q 'annotations:' "$WEBAPP_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} Annotation을 통한 Controller 설정 저장"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Annotation 사용 안함"
    ((FAILED++))
fi

echo "4.5.2 커스텀 Annotation 키 사용"
if grep -q 'k8spatterns.com/' "$WEBAPP_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} 도메인 기반 커스텀 Annotation 키 사용"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 커스텀 Annotation 키 없음"
    ((FAILED++))
fi

# 4.6 RBAC 설정
echo ""
echo -e "${BLUE}[개념 6] RBAC 기반 권한 관리${NC}"
echo ""

echo "4.6.1 ServiceAccount 정의"
if grep -q 'kind: ServiceAccount' "$CONTROLLER_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} 전용 ServiceAccount 정의"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} ServiceAccount 없음"
    ((FAILED++))
fi

echo "4.6.2 RoleBinding을 통한 권한 부여"
if grep -q 'kind: RoleBinding' "$CONTROLLER_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} RoleBinding으로 권한 부여"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} RoleBinding 없음"
    ((FAILED++))
fi

# 4.7 Label Selector 기반 Pod 선택
echo ""
echo -e "${BLUE}[개념 7] Label Selector 기반 Pod 선택${NC}"
echo ""

echo "4.7.1 labelSelector 파라미터 사용"
if grep -q 'labelSelector=' "$CONTROLLER_SCRIPT"; then
    echo -e "${GREEN}[PASS]${NC} API에서 labelSelector 사용"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} labelSelector 사용 안함"
    ((FAILED++))
fi

echo "4.7.2 ConfigMap Annotation과 Pod Label 연동"
SELECTOR=$(grep 'podDeleteSelector' "$WEBAPP_MANIFEST" | grep -o '"[^"]*"' | tr -d '"')
if [ "$SELECTOR" = "app=webapp" ] && grep -q 'app: webapp' "$WEBAPP_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} Annotation($SELECTOR)과 Pod Label 일치"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Annotation과 Label 불일치"
    ((FAILED++))
fi

# 4.8 ConfigMap 환경변수 주입
echo ""
echo -e "${BLUE}[개념 8] ConfigMap을 통한 환경변수 주입${NC}"
echo ""

echo "4.8.1 configMapKeyRef 사용"
if grep -q 'configMapKeyRef:' "$WEBAPP_MANIFEST"; then
    echo -e "${GREEN}[PASS]${NC} ConfigMap에서 환경변수 주입"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} ConfigMap 환경변수 주입 없음"
    ((FAILED++))
fi

echo ""
echo "========================================"
echo "결과: ${PASSED} 통과, ${FAILED} 실패"
echo "========================================"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
