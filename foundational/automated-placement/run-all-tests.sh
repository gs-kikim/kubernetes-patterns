#!/bin/bash

# Automated Placement 전체 테스트 실행 스크립트
# Minikube 환경에서 모든 패턴을 테스트하고 결과를 수집합니다

set -e

echo "================================================"
echo "Kubernetes Automated Placement Pattern"
echo "전체 테스트 실행"
echo "================================================"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 결과 파일
RESULT_FILE="test-results-$(date +%Y%m%d-%H%M%S).txt"
NAMESPACE="automated-placement"

# 함수: 섹션 헤더
print_section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 함수: 테스트 실행 및 결과 확인
run_test() {
    local test_name=$1
    local yaml_file=$2
    
    print_section "테스트: $test_name"
    
    echo "YAML 적용: $yaml_file"
    kubectl apply -f $yaml_file
    
    echo "Pod 생성 대기 중..."
    sleep 10
    
    echo ""
    echo "배치 결과:"
    kubectl get pods -n $NAMESPACE -o wide | grep -E "NAME|$3" || true
    
    echo ""
    echo "이벤트:"
    kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | head -5
}

# 함수: Pod 배치 분석
analyze_placement() {
    echo ""
    echo -e "${BLUE}📊 배치 분석${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 노드별 Pod 수
    echo ""
    echo "노드별 Pod 분포:"
    for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
        count=$(kubectl get pods -n $NAMESPACE --field-selector spec.nodeName=$node --no-headers 2>/dev/null | wc -l)
        echo "  $node: $count개"
    done
    
    # 앱별 분포
    echo ""
    echo "애플리케이션별 분포:"
    for app in node-selector multi-selector node-affinity complex-affinity redis web database api-gateway zone-spread distributed-db ha-web cache gpu-workload system-component spot-workload critical-app; do
        count=$(kubectl get pods -n $NAMESPACE -l app=$app --no-headers 2>/dev/null | wc -l)
        if [ $count -gt 0 ]; then
            echo "  $app: $count개"
        fi
    done
}

# 메인 실행
{
    echo "테스트 시작: $(date)"
    echo ""
    
    # 1. 환경 확인
    print_section "1. 환경 확인"
    
    echo "Minikube 상태:"
    minikube status
    
    echo ""
    echo "노드 정보:"
    kubectl get nodes -o wide
    
    echo ""
    echo "노드 라벨:"
    kubectl get nodes --show-labels
    
    # 2. 네임스페이스 준비
    print_section "2. 네임스페이스 준비"
    
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        echo "기존 네임스페이스 삭제 중..."
        kubectl delete namespace $NAMESPACE --wait=true
    fi
    
    echo "네임스페이스 생성..."
    kubectl create namespace $NAMESPACE
    echo -e "${GREEN}✓ 네임스페이스 준비 완료${NC}"
    
    # 3. Node Selector 테스트
    run_test "Node Selector" "node-selector.yml" "selector"
    
    # 4. Node Affinity 테스트
    run_test "Node Affinity" "node-affinity.yml" "affinity"
    
    # 5. Pod Affinity/Anti-Affinity 테스트
    print_section "테스트: Pod Affinity/Anti-Affinity"
    
    kubectl apply -f pod-affinity.yml
    echo "Pod 생성 대기 중 (30초)..."
    sleep 30
    
    echo ""
    echo "Redis Pod 분포:"
    kubectl get pods -n $NAMESPACE -l app=redis -o wide
    
    echo ""
    echo "Web App 분포:"
    kubectl get pods -n $NAMESPACE -l app=web -o wide
    
    echo ""
    echo "Database 분포:"
    kubectl get pods -n $NAMESPACE -l app=database -o wide
    
    # Anti-Affinity 검증
    echo ""
    echo "Anti-Affinity 검증:"
    redis_nodes=$(kubectl get pods -n $NAMESPACE -l app=redis -o jsonpath='{.items[*].spec.nodeName}')
    unique_nodes=$(echo $redis_nodes | tr ' ' '\n' | sort -u | wc -l)
    total_redis=$(echo $redis_nodes | wc -w)
    echo "Redis Pods: $total_redis개, 배치된 노드: $unique_nodes개"
    
    # 6. Taints와 Tolerations 테스트
    print_section "테스트: Taints와 Tolerations"
    
    # 첫 번째 노드에 Taint 추가
    FIRST_NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
    echo "노드 $FIRST_NODE에 Taint 추가..."
    kubectl taint nodes $FIRST_NODE special=true:NoSchedule --overwrite
    
    kubectl apply -f taints-tolerations.yml
    sleep 15
    
    echo ""
    echo "Toleration이 있는 Pod 확인:"
    kubectl get pods -n $NAMESPACE -o wide | grep -E "gpu-workload|system-component|critical-app" || true
    
    # 7. Topology Spread Constraints 테스트
    print_section "테스트: Topology Spread Constraints"
    
    kubectl apply -f topology-spread.yml
    echo "Topology Spread 배치 대기 중 (30초)..."
    sleep 30
    
    echo ""
    echo "Zone Spread App 분포:"
    kubectl get pods -n $NAMESPACE -l app=zone-spread -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,ZONE:.spec.nodeSelector.topology\\.kubernetes\\.io/zone
    
    echo ""
    echo "HA Web App 분포:"
    kubectl get pods -n $NAMESPACE -l app=ha-web -o wide
    
    # 8. 최종 분석
    print_section "8. 최종 분석"
    
    analyze_placement
    
    # 팬딩 Pod 확인
    echo ""
    echo "팬딩 상태 Pod:"
    pending=$(kubectl get pods -n $NAMESPACE --field-selector status.phase=Pending --no-headers 2>/dev/null | wc -l)
    if [ $pending -gt 0 ]; then
        echo -e "${YELLOW}⚠ $pending개의 Pod가 팬딩 상태입니다${NC}"
        kubectl get pods -n $NAMESPACE --field-selector status.phase=Pending
    else
        echo -e "${GREEN}✓ 모든 Pod가 정상 스케줄링되었습니다${NC}"
    fi
    
    # 실패한 Pod 확인
    echo ""
    echo "실패한 Pod:"
    failed=$(kubectl get pods -n $NAMESPACE --field-selector status.phase=Failed --no-headers 2>/dev/null | wc -l)
    if [ $failed -gt 0 ]; then
        echo -e "${RED}✗ $failed개의 Pod가 실패했습니다${NC}"
        kubectl get pods -n $NAMESPACE --field-selector status.phase=Failed
    else
        echo -e "${GREEN}✓ 실패한 Pod가 없습니다${NC}"
    fi
    
    # 9. 리소스 사용량
    print_section "9. 리소스 사용량"
    
    echo "노드 리소스:"
    kubectl top nodes 2>/dev/null || echo "Metrics Server가 아직 준비되지 않았습니다"
    
    echo ""
    echo "Pod 리소스 (상위 10개):"
    kubectl top pods -n $NAMESPACE --sort-by=cpu 2>/dev/null | head -11 || echo "Metrics 수집 중..."
    
    # 10. 테스트 요약
    print_section "10. 테스트 요약"
    
    total_pods=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
    running_pods=$(kubectl get pods -n $NAMESPACE --field-selector status.phase=Running --no-headers 2>/dev/null | wc -l)
    
    echo "전체 Pod: $total_pods개"
    echo "실행 중: $running_pods개"
    echo "팬딩: $pending개"
    echo "실패: $failed개"
    echo ""
    echo -e "${GREEN}테스트 완료: $(date)${NC}"
    
    # Taint 정리
    echo ""
    echo "Taint 정리 중..."
    kubectl taint nodes $FIRST_NODE special=true:NoSchedule- 2>/dev/null || true
    
} | tee $RESULT_FILE

echo ""
echo "================================================"
echo -e "${GREEN}모든 테스트가 완료되었습니다!${NC}"
echo "================================================"
echo ""
echo "결과가 $RESULT_FILE 파일에 저장되었습니다."
echo ""
echo "정리하려면:"
echo "  kubectl delete namespace $NAMESPACE"
echo ""
echo "클러스터를 삭제하려면:"
echo "  minikube delete"