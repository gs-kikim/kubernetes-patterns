#!/bin/bash

echo "========================================="
echo "Kubernetes Managed Lifecycle 전체 테스트"
echo "========================================="

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 테스트 실행 함수
run_test_suite() {
    local test_name=$1
    local test_script=$2
    
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}$test_name 실행 중...${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ -f "$test_script" ]; then
        chmod +x "$test_script"
        if bash "$test_script"; then
            echo -e "${GREEN}✓ $test_name 완료${NC}"
            return 0
        else
            echo -e "${RED}✗ $test_name 실패${NC}"
            return 1
        fi
    else
        echo -e "${RED}테스트 스크립트를 찾을 수 없음: $test_script${NC}"
        return 1
    fi
}

# 시작 시간 기록
START_TIME=$(date +%s)

echo -e "${YELLOW}테스트 환경 준비 중...${NC}"

# namespace 생성 (옵션)
read -p "테스트용 namespace를 생성하시겠습니까? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    NAMESPACE="lifecycle-test"
    kubectl create namespace $NAMESPACE 2>/dev/null || echo "Namespace already exists"
    kubectl config set-context --current --namespace=$NAMESPACE
    echo -e "${GREEN}Namespace '$NAMESPACE' 사용 중${NC}"
fi

# 테스트 순서
echo
echo -e "${BLUE}실행할 테스트 목록:${NC}"
echo "1. PostStart Hook 테스트"
echo "2. PreStop Hook 테스트"
echo "3. Graceful Shutdown 테스트"
echo "4. 완전한 수명주기 통합 테스트"

echo
read -p "모든 테스트를 순차적으로 실행하시겠습니까? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # 모든 테스트 실행
    TESTS=(
        "PostStart Hook 테스트:test-poststart.sh"
        "PreStop Hook 테스트:test-prestop.sh"
        "Graceful Shutdown 테스트:test-graceful-shutdown.sh"
        "완전한 수명주기 통합 테스트:test-complete-lifecycle.sh"
    )
    
    PASSED=0
    FAILED=0
    
    for test in "${TESTS[@]}"; do
        IFS=':' read -r name script <<< "$test"
        if run_test_suite "$name" "$script"; then
            ((PASSED++))
        else
            ((FAILED++))
        fi
        
        # 다음 테스트 전 대기
        if [ "$name" != "완전한 수명주기 통합 테스트" ]; then
            echo
            read -p "다음 테스트를 계속하시겠습니까? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                break
            fi
        fi
    done
    
else
    # 개별 테스트 선택
    echo -e "${YELLOW}실행할 테스트를 선택하세요:${NC}"
    select test in "PostStart Hook" "PreStop Hook" "Graceful Shutdown" "완전한 수명주기" "종료"; do
        case $test in
            "PostStart Hook")
                run_test_suite "PostStart Hook 테스트" "test-poststart.sh"
                ;;
            "PreStop Hook")
                run_test_suite "PreStop Hook 테스트" "test-prestop.sh"
                ;;
            "Graceful Shutdown")
                run_test_suite "Graceful Shutdown 테스트" "test-graceful-shutdown.sh"
                ;;
            "완전한 수명주기")
                run_test_suite "완전한 수명주기 통합 테스트" "test-complete-lifecycle.sh"
                ;;
            "종료")
                break
                ;;
        esac
    done
fi

# 종료 시간 및 소요 시간 계산
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${PURPLE}테스트 실행 완료${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 결과 요약
if [ ! -z "$PASSED" ]; then
    echo -e "${GREEN}성공: $PASSED${NC}"
    echo -e "${RED}실패: $FAILED${NC}"
fi

echo -e "${BLUE}총 소요 시간: ${DURATION}초${NC}"

# 최종 정리
echo
echo -e "${YELLOW}최종 정리${NC}"
read -p "모든 테스트 리소스를 정리하시겠습니까? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "리소스 정리 중..."
    
    # 모든 테스트 Pod 삭제
    kubectl delete pods --all --ignore-not-found=true
    
    # ConfigMap 삭제
    kubectl delete configmap --all --ignore-not-found=true
    
    # Job 삭제
    kubectl delete jobs --all --ignore-not-found=true
    
    # Service 삭제
    kubectl delete service --all --ignore-not-found=true
    
    # Deployment 삭제
    kubectl delete deployment --all --ignore-not-found=true
    
    # namespace 삭제 (생성한 경우)
    if [ ! -z "$NAMESPACE" ]; then
        read -p "Namespace '$NAMESPACE'도 삭제하시겠습니까? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kubectl delete namespace $NAMESPACE
            kubectl config set-context --current --namespace=default
        fi
    fi
    
    echo -e "${GREEN}정리 완료!${NC}"
fi

echo
echo -e "${GREEN}모든 테스트가 완료되었습니다!${NC}"
echo -e "${BLUE}자세한 내용은 README.md를 참조하세요.${NC}"