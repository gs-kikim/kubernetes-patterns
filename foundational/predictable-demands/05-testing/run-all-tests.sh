#!/bin/bash

# run-all-tests.sh
# 모든 Predictable Demands 패턴 테스트 실행

set +e  # 에러가 발생해도 계속 진행

echo "=== Predictable Demands Pattern - Complete Test Suite ==="
echo "Starting at: $(date)"
echo

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 결과 추적
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 스크립트 디렉토리 확인
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 실행 권한 부여
echo -e "${YELLOW}Setting execute permissions on test scripts...${NC}"
chmod +x "$SCRIPT_DIR"/*.sh

# 테스트 실행 함수
run_test_suite() {
    local test_script=$1
    local test_name=$2
    
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}Running: $test_name${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    ((TOTAL_TESTS++))
    
    if "$SCRIPT_DIR/$test_script"; then
        echo -e "${GREEN}✓ $test_name completed successfully${NC}"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}✗ $test_name failed${NC}"
        ((FAILED_TESTS++))
    fi
    
    echo -e "${BLUE}========================================${NC}\n"
    
    # 테스트 간 대기
    sleep 5
}

# 사전 확인
echo -e "${YELLOW}Pre-flight checks...${NC}"

# Minikube 상태 확인
if command -v minikube &> /dev/null; then
    echo "Checking Minikube status..."
    if ! minikube status &> /dev/null; then
        echo -e "${RED}Error: Minikube is not running. Please start it with: minikube start${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Minikube is running${NC}"
fi

# kubectl 연결 확인
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

# metrics-server 확인
echo "Checking metrics-server..."
if kubectl get deployment metrics-server -n kube-system &> /dev/null; then
    echo -e "${GREEN}✓ metrics-server is deployed${NC}"
    # 메트릭 사용 가능 여부 확인
    if ! kubectl top nodes &> /dev/null; then
        echo -e "${YELLOW}Warning: metrics-server is deployed but metrics not yet available. Waiting...${NC}"
        sleep 30
    fi
else
    echo -e "${YELLOW}Warning: metrics-server not found. Installing...${NC}"
    minikube addons enable metrics-server
    echo "Waiting for metrics-server to be ready..."
    sleep 45
fi

# 클러스터 리소스 상태 확인
echo -e "${BLUE}Current cluster resource status:${NC}"
kubectl top nodes || echo "Metrics not available"
echo

# Minikube 리소스 확인
if command -v minikube &> /dev/null; then
    echo -e "${BLUE}Minikube configuration:${NC}"
    echo "CPUs: $(minikube config get cpus || echo '2')"
    echo "Memory: $(minikube config get memory || echo '2048')MB"
    echo
fi

# 기존 테스트 리소스 정리
echo -e "${YELLOW}Cleaning up any existing test resources...${NC}"
"$SCRIPT_DIR/cleanup.sh" || true

# 테스트 실행
echo -e "${GREEN}Starting test suites...${NC}"

# 1. 런타임 의존성 테스트
run_test_suite "test-dependencies.sh" "Runtime Dependencies Tests"

# 2. 리소스 제한 및 QoS 테스트
run_test_suite "test-resource-limits.sh" "Resource Limits and QoS Tests"

# 3. Pod 우선순위 및 선점 테스트
run_test_suite "test-priority-preemption.sh" "Pod Priority and Preemption Tests"

# 4. ResourceQuota 및 LimitRange 테스트
run_test_suite "test-quotas.sh" "ResourceQuota and LimitRange Tests"

# 최종 정리
echo -e "${YELLOW}Final cleanup...${NC}"
"$SCRIPT_DIR/cleanup.sh"

# 결과 요약
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Test Suite Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Total test suites run: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "${RED}Failed: $FAILED_TESTS${NC}"
echo -e "Completion time: $(date)"

# 전체 결과
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}✓ All test suites passed successfully!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some test suites failed. Please check the logs above.${NC}"
    exit 1
fi