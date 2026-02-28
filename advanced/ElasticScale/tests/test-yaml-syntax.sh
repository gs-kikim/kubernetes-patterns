#!/bin/bash

# Test 1: YAML 구문 검증 테스트
# Elastic Scale 패턴의 모든 Kubernetes 매니페스트 YAML 구문 유효성 확인

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "Test 1: YAML 구문 검증"
echo "========================================"

PASSED=0
FAILED=0

# kubectl 또는 python3 사용 가능 여부 확인
if command -v python3 &> /dev/null; then
    VALIDATOR="python"
elif command -v kubectl &> /dev/null; then
    VALIDATOR="kubectl"
else
    echo -e "${YELLOW}[SKIP] kubectl 또는 python3이 필요합니다${NC}"
    exit 0
fi

validate_yaml() {
    local file=$1
    local filename=$(basename "$file")

    if [ "$VALIDATOR" = "python" ]; then
        # Python으로 YAML 파싱 검증 (멀티 도큐먼트 지원)
        if python3 -c "
import yaml, sys
with open('$file') as f:
    list(yaml.safe_load_all(f))
" 2>/dev/null; then
            echo -e "${GREEN}[PASS]${NC} $filename - YAML 구문 유효"
            ((PASSED++))
            return 0
        else
            echo -e "${RED}[FAIL]${NC} $filename - YAML 구문 오류"
            ((FAILED++))
            return 1
        fi
    else
        # kubectl dry-run 검증 (클러스터 연결 필요할 수 있음)
        if kubectl apply --dry-run=client -f "$file" > /dev/null 2>&1; then
            echo -e "${GREEN}[PASS]${NC} $filename - YAML 구문 유효"
            ((PASSED++))
            return 0
        else
            echo -e "${RED}[FAIL]${NC} $filename - YAML 구문 오류"
            kubectl apply --dry-run=client -f "$file" 2>&1 | head -5
            ((FAILED++))
            return 1
        fi
    fi
}

echo ""
echo "매니페스트 파일 검증 중..."
echo ""

shopt -s nullglob
for file in "$MANIFEST_DIR"/*.yml "$MANIFEST_DIR"/*.yaml; do
    if [ -f "$file" ]; then
        validate_yaml "$file"
    fi
done
shopt -u nullglob

echo ""
echo "========================================"
echo "결과: ${PASSED} 통과, ${FAILED} 실패"
echo "========================================"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
