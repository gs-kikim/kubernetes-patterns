#!/bin/bash

# Elastic Scale 패턴 전체 테스트 실행 스크립트
# Chapter 29: 탄력적 스케일링 — HPA, VPA, Behavior 정책

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "Elastic Scale 패턴 전체 테스트"
echo "Kubernetes Patterns — Chapter 29"
echo "========================================"
echo ""
echo "테스트 시작 시간: $(date)"
echo ""

TOTAL_PASSED=0
TOTAL_FAILED=0
TEST_RESULTS=()

run_test() {
    local test_script=$1
    local test_name=$2

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}실행: $test_name${NC}"
    echo -e "${BLUE}========================================${NC}"

    if bash "$SCRIPT_DIR/$test_script"; then
        TEST_RESULTS+=("${GREEN}[PASS]${NC} $test_name")
        ((TOTAL_PASSED++))
    else
        TEST_RESULTS+=("${RED}[FAIL]${NC} $test_name")
        ((TOTAL_FAILED++))
    fi
}

# 테스트 1: YAML 구문 검증
run_test "test-yaml-syntax.sh" "Test 1: YAML 구문 검증"

# 테스트 2: 매니페스트 구조 검증
run_test "test-manifest-structure.sh" "Test 2: 매니페스트 구조 검증"

# 테스트 3: 블로그 핵심 개념 검증
run_test "test-blog-concepts.sh" "Test 3: 블로그 핵심 개념 검증"

# 테스트 4: 클러스터 배포 테스트 (선택적)
echo ""
echo -e "${YELLOW}테스트 4: 클러스터 배포 테스트를 실행하시겠습니까?${NC}"
echo "이 테스트는 minikube + metrics-server가 필요합니다."
echo "부하 생성 후 HPA 스케일업/다운을 관찰합니다 (약 5~10분 소요)."
read -p "실행? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    run_test "test-cluster-deploy.sh" "Test 4: 클러스터 배포 테스트 (HPA 동작 검증)"
else
    echo -e "${YELLOW}[SKIP]${NC} 클러스터 배포 테스트 건너뜀"
    TEST_RESULTS+=("${YELLOW}[SKIP]${NC} Test 4: 클러스터 배포 테스트")
fi

# 최종 결과 요약
echo ""
echo "========================================"
echo "테스트 결과 요약"
echo "========================================"
echo ""
for result in "${TEST_RESULTS[@]}"; do
    echo -e "$result"
done

echo ""
echo "========================================"
echo -e "전체 결과: ${GREEN}$TOTAL_PASSED 통과${NC}, ${RED}$TOTAL_FAILED 실패${NC}"
echo "========================================"
echo ""
echo "테스트 종료 시간: $(date)"

if [ $TOTAL_FAILED -gt 0 ]; then
    exit 1
fi
