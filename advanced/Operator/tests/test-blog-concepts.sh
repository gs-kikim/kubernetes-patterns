#!/bin/bash

# Test 5: README 핵심 개념 검증 테스트
# Operator 패턴 README에 핵심 개념이 포함되어 있는지 확인

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
README_FILE="$SCRIPT_DIR/../README.md"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "Test 5: README 핵심 개념 검증"
echo "========================================"

PASSED=0
FAILED=0

# 5.1 README 파일 존재 확인
echo ""
echo "5.1 README.md 파일 존재 확인"
if [ -f "$README_FILE" ]; then
    echo -e "${GREEN}[PASS]${NC} README.md 파일 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} README.md 파일 없음"
    ((FAILED++))
    exit 1
fi

# 5.2 Controller vs Operator 차이점 설명 확인
echo ""
echo "5.2 Controller vs Operator 차이점 설명 확인"
if grep -qi 'controller.*operator\|controller vs operator\|Controller.*Operator' "$README_FILE"; then
    echo -e "${GREEN}[PASS]${NC} Controller vs Operator 비교 설명 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Controller vs Operator 비교 설명 없음"
    ((FAILED++))
fi

# 5.3 CRD 개념 설명 확인
echo ""
echo "5.3 CRD (Custom Resource Definition) 개념 설명 확인"
if grep -qi 'Custom Resource Definition\|CRD' "$README_FILE"; then
    echo -e "${GREEN}[PASS]${NC} CRD 개념 설명 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} CRD 개념 설명 없음"
    ((FAILED++))
fi

# 5.4 Reconciliation Loop 설명 확인
echo ""
echo "5.4 Reconciliation Loop 설명 확인"
if grep -qi 'Reconciliation\|reconcile\|Observe.*Analyze.*Act' "$README_FILE"; then
    echo -e "${GREEN}[PASS]${NC} Reconciliation Loop 설명 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Reconciliation Loop 설명 없음"
    ((FAILED++))
fi

# 5.5 ConfigWatcher 예제 설명 확인
echo ""
echo "5.5 ConfigWatcher 예제 설명 확인"
if grep -qi 'ConfigWatcher' "$README_FILE"; then
    echo -e "${GREEN}[PASS]${NC} ConfigWatcher 예제 설명 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} ConfigWatcher 예제 설명 없음"
    ((FAILED++))
fi

# 5.6 사용법(kubectl 명령어) 설명 확인
echo ""
echo "5.6 사용법(kubectl 명령어) 설명 확인"
if grep -q 'kubectl apply' "$README_FILE"; then
    echo -e "${GREEN}[PASS]${NC} kubectl 사용법 설명 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} kubectl 사용법 설명 없음"
    ((FAILED++))
fi

# 5.7 아키텍처 다이어그램 확인
echo ""
echo "5.7 아키텍처 다이어그램 확인"
if grep -q 'kubeapi-proxy\|sidecar' "$README_FILE"; then
    echo -e "${GREEN}[PASS]${NC} 아키텍처 설명 존재 (sidecar 패턴)"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 아키텍처 설명 없음"
    ((FAILED++))
fi

# 5.8 podSelector 설명 확인
echo ""
echo "5.8 podSelector 설명 확인"
if grep -qi 'podSelector' "$README_FILE"; then
    echo -e "${GREEN}[PASS]${NC} podSelector 설명 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} podSelector 설명 없음"
    ((FAILED++))
fi

echo ""
echo "========================================"
echo "결과: ${PASSED} 통과, ${FAILED} 실패"
echo "========================================"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
