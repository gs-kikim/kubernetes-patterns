#!/bin/bash

# Test 2: CRD 구조 검증 테스트
# ConfigWatcher CRD의 구조적 요소가 올바르게 정의되었는지 확인

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "Test 2: CRD 구조 검증"
echo "========================================"

PASSED=0
FAILED=0

CRD_FILE="$MANIFEST_DIR/config-watcher-crd.yml"

# 2.1 CRD 파일 존재 확인
echo ""
echo "2.1 CRD 파일 존재 확인"
if [ -f "$CRD_FILE" ]; then
    echo -e "${GREEN}[PASS]${NC} config-watcher-crd.yml 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} config-watcher-crd.yml 없음"
    ((FAILED++))
    exit 1
fi

# 2.2 apiVersion 확인
echo ""
echo "2.2 apiVersion 확인 (apiextensions.k8s.io/v1)"
if grep -q 'apiVersion: apiextensions.k8s.io/v1' "$CRD_FILE"; then
    echo -e "${GREEN}[PASS]${NC} apiVersion: apiextensions.k8s.io/v1"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 올바른 apiVersion이 없음"
    ((FAILED++))
fi

# 2.3 Kind 확인
echo ""
echo "2.3 Kind 확인 (CustomResourceDefinition)"
if grep -q 'kind: CustomResourceDefinition' "$CRD_FILE"; then
    echo -e "${GREEN}[PASS]${NC} kind: CustomResourceDefinition"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} kind가 CustomResourceDefinition이 아님"
    ((FAILED++))
fi

# 2.4 API Group 확인
echo ""
echo "2.4 API Group 확인 (k8spatterns.com)"
if grep -q 'group: k8spatterns.com' "$CRD_FILE"; then
    echo -e "${GREEN}[PASS]${NC} API Group: k8spatterns.com"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} API Group이 k8spatterns.com이 아님"
    ((FAILED++))
fi

# 2.5 Scope 확인
echo ""
echo "2.5 Scope 확인 (Namespaced)"
if grep -q 'scope: Namespaced' "$CRD_FILE"; then
    echo -e "${GREEN}[PASS]${NC} scope: Namespaced"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} scope가 Namespaced가 아님"
    ((FAILED++))
fi

# 2.6 Kind 이름 확인
echo ""
echo "2.6 CRD Kind 이름 확인 (ConfigWatcher)"
if grep -q 'kind: ConfigWatcher' "$CRD_FILE"; then
    echo -e "${GREEN}[PASS]${NC} kind: ConfigWatcher"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} kind가 ConfigWatcher가 아님"
    ((FAILED++))
fi

# 2.7 Plural 이름 확인
echo ""
echo "2.7 Plural 이름 확인 (configwatchers)"
if grep -q 'plural: configwatchers' "$CRD_FILE"; then
    echo -e "${GREEN}[PASS]${NC} plural: configwatchers"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} plural 이름이 올바르지 않음"
    ((FAILED++))
fi

# 2.8 Short Name 확인
echo ""
echo "2.8 Short Name 확인 (cw)"
if grep -q '\- cw' "$CRD_FILE" || grep -q '- cw' "$CRD_FILE"; then
    echo -e "${GREEN}[PASS]${NC} shortName: cw"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} shortName 'cw'가 없음"
    ((FAILED++))
fi

# 2.9 spec.configMap 필드 확인
echo ""
echo "2.9 spec.configMap 필드 확인"
if grep -q 'configMap:' "$CRD_FILE" && grep -q 'type: string' "$CRD_FILE"; then
    echo -e "${GREEN}[PASS]${NC} spec.configMap 필드 정의 존재 (type: string)"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} spec.configMap 필드 정의 없음"
    ((FAILED++))
fi

# 2.10 spec.podSelector 필드 확인
echo ""
echo "2.10 spec.podSelector 필드 확인"
if grep -q 'podSelector:' "$CRD_FILE"; then
    echo -e "${GREEN}[PASS]${NC} spec.podSelector 필드 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} spec.podSelector 필드 정의 없음"
    ((FAILED++))
fi

# 2.11 matchLabels 필드 확인
echo ""
echo "2.11 matchLabels 필드 확인"
if grep -q 'matchLabels:' "$CRD_FILE"; then
    echo -e "${GREEN}[PASS]${NC} podSelector.matchLabels 필드 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} podSelector.matchLabels 필드 없음"
    ((FAILED++))
fi

# 2.12 OpenAPIV3Schema 확인
echo ""
echo "2.12 OpenAPIV3Schema 유효성 검증 스키마 확인"
if grep -q 'openAPIV3Schema:' "$CRD_FILE"; then
    echo -e "${GREEN}[PASS]${NC} openAPIV3Schema 정의 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} openAPIV3Schema 정의 없음"
    ((FAILED++))
fi

# 2.13 required 필드 확인
echo ""
echo "2.13 required 필드 확인 (configMap, podSelector)"
if grep -A2 'required:' "$CRD_FILE" | grep -q 'configMap' && grep -A2 'required:' "$CRD_FILE" | grep -q 'podSelector'; then
    echo -e "${GREEN}[PASS]${NC} required 필드에 configMap, podSelector 포함"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} required 필드 정의가 올바르지 않음"
    ((FAILED++))
fi

# 2.14 additionalPrinterColumns 확인
echo ""
echo "2.14 additionalPrinterColumns 확인"
if grep -q 'additionalPrinterColumns:' "$CRD_FILE"; then
    echo -e "${GREEN}[PASS]${NC} additionalPrinterColumns 정의 존재"
    ((PASSED++))
else
    echo -e "${YELLOW}[WARN]${NC} additionalPrinterColumns 정의 없음 (선택사항)"
fi

echo ""
echo "========================================"
echo "결과: ${PASSED} 통과, ${FAILED} 실패"
echo "========================================"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
