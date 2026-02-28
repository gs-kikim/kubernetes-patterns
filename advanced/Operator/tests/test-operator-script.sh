#!/bin/bash

# Test 3: Operator 셸 스크립트 로직 검증 테스트
# Operator의 핵심 로직이 올바르게 구현되었는지 확인

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "Test 3: Operator 스크립트 로직 검증"
echo "========================================"

PASSED=0
FAILED=0

OPERATOR_MANIFEST="$MANIFEST_DIR/config-watcher-operator.yml"

# Operator 스크립트를 매니페스트에서 추출
SCRIPT_CONTENT=$(sed -n '/config-watcher-operator.sh: |/,/^---/p' "$OPERATOR_MANIFEST")

# 3.1 start_event_loop 함수 존재 확인
echo ""
echo "3.1 start_event_loop 함수 존재 확인"
if echo "$SCRIPT_CONTENT" | grep -q 'start_event_loop'; then
    echo -e "${GREEN}[PASS]${NC} start_event_loop 함수 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} start_event_loop 함수 없음"
    ((FAILED++))
fi

# 3.2 delete_pods_with_selector 함수 존재 확인
echo ""
echo "3.2 delete_pods_with_selector 함수 존재 확인"
if echo "$SCRIPT_CONTENT" | grep -q 'delete_pods_with_selector'; then
    echo -e "${GREEN}[PASS]${NC} delete_pods_with_selector 함수 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} delete_pods_with_selector 함수 없음"
    ((FAILED++))
fi

# 3.3 ConfigMap Watch API 엔드포인트 확인
echo ""
echo "3.3 ConfigMap Watch API 엔드포인트 확인"
if echo "$SCRIPT_CONTENT" | grep -q 'configmaps?watch=true'; then
    echo -e "${GREEN}[PASS]${NC} ConfigMap Watch API 엔드포인트 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} ConfigMap Watch API 엔드포인트 없음"
    ((FAILED++))
fi

# 3.4 ConfigWatcher CRD 조회 엔드포인트 확인 (Controller와의 핵심 차이점)
echo ""
echo "3.4 ConfigWatcher CRD 조회 엔드포인트 확인"
if echo "$SCRIPT_CONTENT" | grep -q 'k8spatterns.com/v1.*configwatchers'; then
    echo -e "${GREEN}[PASS]${NC} ConfigWatcher CRD API 엔드포인트 존재 (/apis/k8spatterns.com/v1/.../configwatchers)"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} ConfigWatcher CRD API 엔드포인트 없음"
    ((FAILED++))
fi

# 3.5 MODIFIED 이벤트 처리 로직 확인
echo ""
echo "3.5 MODIFIED 이벤트 처리 로직 확인"
if echo "$SCRIPT_CONTENT" | grep -q 'MODIFIED'; then
    echo -e "${GREEN}[PASS]${NC} MODIFIED 이벤트 필터링 로직 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} MODIFIED 이벤트 처리 없음"
    ((FAILED++))
fi

# 3.6 jq를 사용한 JSON 파싱 확인
echo ""
echo "3.6 jq를 사용한 JSON 파싱 확인"
if echo "$SCRIPT_CONTENT" | grep -q 'jq'; then
    echo -e "${GREEN}[PASS]${NC} jq JSON 파싱 사용"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} jq 사용 없음"
    ((FAILED++))
fi

# 3.7 curl을 사용한 API 호출 확인
echo ""
echo "3.7 curl을 사용한 API 호출 확인"
if echo "$SCRIPT_CONTENT" | grep -q 'curl'; then
    echo -e "${GREEN}[PASS]${NC} curl API 호출 사용"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} curl 사용 없음"
    ((FAILED++))
fi

# 3.8 Pod 삭제 HTTP DELETE 메서드 확인
echo ""
echo "3.8 Pod 삭제 HTTP DELETE 메서드 확인"
if echo "$SCRIPT_CONTENT" | grep -q '\-X DELETE'; then
    echo -e "${GREEN}[PASS]${NC} HTTP DELETE 메서드 사용"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} HTTP DELETE 메서드 없음"
    ((FAILED++))
fi

# 3.9 WATCH_NAMESPACE 환경변수 사용 확인
echo ""
echo "3.9 WATCH_NAMESPACE 환경변수 사용 확인"
if echo "$SCRIPT_CONTENT" | grep -q 'WATCH_NAMESPACE'; then
    echo -e "${GREEN}[PASS]${NC} WATCH_NAMESPACE 환경변수 사용"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} WATCH_NAMESPACE 환경변수 없음"
    ((FAILED++))
fi

# 3.10 localhost:8001 (kubeapi-proxy) 사용 확인
echo ""
echo "3.10 localhost:8001 (kubeapi-proxy) 사용 확인"
if echo "$SCRIPT_CONTENT" | grep -q 'localhost:8001'; then
    echo -e "${GREEN}[PASS]${NC} kubeapi-proxy (localhost:8001) 사용"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} kubeapi-proxy 엔드포인트 없음"
    ((FAILED++))
fi

# 3.11 ConfigMap 이름 기반 ConfigWatcher 필터링 확인
echo ""
echo "3.11 spec.configMap 기반 ConfigWatcher 필터링 확인"
if echo "$SCRIPT_CONTENT" | grep -q 'spec.configMap'; then
    echo -e "${GREEN}[PASS]${NC} spec.configMap 필터링 로직 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} spec.configMap 필터링 로직 없음"
    ((FAILED++))
fi

# 3.12 podSelector.matchLabels에서 라벨 셀렉터 추출 확인
echo ""
echo "3.12 podSelector.matchLabels에서 라벨 셀렉터 추출 확인"
if echo "$SCRIPT_CONTENT" | grep -q 'podSelector\|matchLabels'; then
    echo -e "${GREEN}[PASS]${NC} podSelector/matchLabels 라벨 추출 로직 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} podSelector/matchLabels 라벨 추출 없음"
    ((FAILED++))
fi

echo ""
echo "========================================"
echo "결과: ${PASSED} 통과, ${FAILED} 실패"
echo "========================================"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
