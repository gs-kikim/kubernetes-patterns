#!/bin/bash

# Test 2: Controller 스크립트 로직 검증 테스트
# 블로그에서 설명한 Shell Script Controller의 핵심 로직 검증

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"
CONTROLLER_SCRIPT="$MANIFEST_DIR/config-watcher-controller.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "Test 2: Controller 스크립트 로직 검증"
echo "========================================"

PASSED=0
FAILED=0

# 스크립트 파일 존재 확인
echo ""
echo "2.1 스크립트 파일 존재 확인"
if [ -f "$CONTROLLER_SCRIPT" ]; then
    echo -e "${GREEN}[PASS]${NC} config-watcher-controller.sh 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} config-watcher-controller.sh 없음"
    ((FAILED++))
    exit 1
fi

# 2.2 WATCH_NAMESPACE 환경 변수 처리 확인
echo ""
echo "2.2 WATCH_NAMESPACE 환경 변수 처리 확인"
if grep -q 'namespace=\${WATCH_NAMESPACE:-default}' "$CONTROLLER_SCRIPT"; then
    echo -e "${GREEN}[PASS]${NC} WATCH_NAMESPACE 기본값(default) 처리 로직 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} WATCH_NAMESPACE 기본값 처리 로직 없음"
    ((FAILED++))
fi

# 2.3 Kubernetes API Watch 호출 확인 (Hanging GET)
echo ""
echo "2.3 Kubernetes API Watch 호출 확인 (Hanging GET)"
if grep -q 'configmaps?watch=true' "$CONTROLLER_SCRIPT"; then
    echo -e "${GREEN}[PASS]${NC} ConfigMap Watch API 호출 (watch=true 파라미터) 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} ConfigMap Watch API 호출 없음"
    ((FAILED++))
fi

# 2.4 Ambassador 패턴 - localhost:8001 사용 확인
echo ""
echo "2.4 Ambassador 패턴 - localhost:8001 사용 확인"
if grep -q 'base=http://localhost:8001' "$CONTROLLER_SCRIPT"; then
    echo -e "${GREEN}[PASS]${NC} Ambassador 프록시(localhost:8001) 사용"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Ambassador 프록시 설정 없음"
    ((FAILED++))
fi

# 2.5 이벤트 타입 파싱 확인 (jq 사용)
echo ""
echo "2.5 이벤트 타입 파싱 확인"
if grep -q "jq -r .type" "$CONTROLLER_SCRIPT"; then
    echo -e "${GREEN}[PASS]${NC} 이벤트 타입 파싱(jq -r .type) 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 이벤트 타입 파싱 없음"
    ((FAILED++))
fi

# 2.6 Annotation 추출 로직 확인
echo ""
echo "2.6 k8spatterns.com/podDeleteSelector Annotation 처리 확인"
if grep -q 'k8spatterns.com/podDeleteSelector' "$CONTROLLER_SCRIPT"; then
    echo -e "${GREEN}[PASS]${NC} podDeleteSelector Annotation 처리 로직 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} podDeleteSelector Annotation 처리 없음"
    ((FAILED++))
fi

# 2.7 MODIFIED 이벤트 조건 확인
echo ""
echo "2.7 MODIFIED 이벤트 조건 확인"
if grep -q 'type = "MODIFIED"' "$CONTROLLER_SCRIPT"; then
    echo -e "${GREEN}[PASS]${NC} MODIFIED 이벤트 조건 처리 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} MODIFIED 이벤트 조건 처리 없음"
    ((FAILED++))
fi

# 2.8 Pod 삭제 함수 존재 확인
echo ""
echo "2.8 Pod 삭제 함수 존재 확인"
if grep -q 'delete_pods_with_selector' "$CONTROLLER_SCRIPT"; then
    echo -e "${GREEN}[PASS]${NC} Pod 삭제 함수(delete_pods_with_selector) 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Pod 삭제 함수 없음"
    ((FAILED++))
fi

# 2.9 labelSelector를 사용한 Pod 조회 확인
echo ""
echo "2.9 labelSelector를 사용한 Pod 조회 확인"
if grep -q 'labelSelector=' "$CONTROLLER_SCRIPT"; then
    echo -e "${GREEN}[PASS]${NC} labelSelector 기반 Pod 조회 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} labelSelector 기반 Pod 조회 없음"
    ((FAILED++))
fi

# 2.10 Pod DELETE API 호출 확인
echo ""
echo "2.10 Pod DELETE API 호출 확인"
if grep -q 'curl -s -X DELETE' "$CONTROLLER_SCRIPT"; then
    echo -e "${GREEN}[PASS]${NC} Pod DELETE API 호출 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Pod DELETE API 호출 없음"
    ((FAILED++))
fi

# 2.11 Shell 문법 검증
echo ""
echo "2.11 Shell 스크립트 문법 검증"
if bash -n "$CONTROLLER_SCRIPT" 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} Shell 스크립트 문법 유효"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Shell 스크립트 문법 오류"
    bash -n "$CONTROLLER_SCRIPT"
    ((FAILED++))
fi

echo ""
echo "========================================"
echo "결과: ${PASSED} 통과, ${FAILED} 실패"
echo "========================================"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
