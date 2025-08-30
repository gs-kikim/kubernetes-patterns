#!/bin/bash

# Automated Placement 패턴 테스트 스크립트
# 이 스크립트는 다양한 배치 전략을 테스트합니다

set -e

echo "============================================"
echo "Kubernetes Automated Placement Pattern Test"
echo "============================================"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 네임스페이스 생성
NAMESPACE="automated-placement"

# 함수: 명령 실행 및 결과 출력
run_command() {
    echo -e "${YELLOW}실행: $1${NC}"
    eval $1
    echo ""
}

# 함수: 성공 메시지
success_msg() {
    echo -e "${GREEN}✓ $1${NC}"
}

# 함수: 에러 메시지
error_msg() {
    echo -e "${RED}✗ $1${NC}"
}

# 함수: Pod 상태 확인
check_pod_status() {
    local pod_name=$1
    local namespace=$2
    local max_wait=60
    local count=0
    
    echo "Pod $pod_name 상태 확인 중..."
    while [ $count -lt $max_wait ]; do
        status=$(kubectl get pod $pod_name -n $namespace -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
        if [ "$status" = "Running" ] || [ "$status" = "Succeeded" ]; then
            success_msg "Pod $pod_name이 $status 상태입니다."
            return 0
        elif [ "$status" = "Failed" ] || [ "$status" = "Error" ]; then
            error_msg "Pod $pod_name이 실패했습니다. 상태: $status"
            kubectl describe pod $pod_name -n $namespace | tail -20
            return 1
        fi
        sleep 2
        count=$((count + 2))
    done
    error_msg "Pod $pod_name이 시간 초과되었습니다."
    return 1
}

# 테스트 시작
echo ""
echo "1. 환경 준비"
echo "============"

# 네임스페이스 확인 및 생성
if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo "네임스페이스 $NAMESPACE가 이미 존재합니다. 삭제 후 재생성합니다."
    kubectl delete namespace $NAMESPACE --wait=true
fi

run_command "kubectl create namespace $NAMESPACE"
success_msg "네임스페이스 생성 완료"

# 노드 정보 확인
echo ""
echo "2. 클러스터 노드 정보"
echo "===================="
run_command "kubectl get nodes --show-labels"

# 노드 라벨링 (테스트 환경용)
echo ""
echo "3. 노드 라벨링 (테스트용)"
echo "======================="

# 첫 번째 노드에 라벨 추가
FIRST_NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
if [ ! -z "$FIRST_NODE" ]; then
    run_command "kubectl label node $FIRST_NODE disktype=ssd --overwrite"
    run_command "kubectl label node $FIRST_NODE environment=production --overwrite"
    success_msg "노드 $FIRST_NODE에 라벨 추가 완료"
fi

# Node Selector 테스트
echo ""
echo "4. Node Selector 테스트"
echo "======================"
run_command "kubectl apply -f node-selector.yml"

# Pod 상태 확인
sleep 5
echo "Node Selector Pod 배치 확인:"
kubectl get pods -n $NAMESPACE -o wide | grep node-selector

# Pod가 정상적으로 스케줄링되었는지 확인
if kubectl get pod node-selector-pod -n $NAMESPACE &> /dev/null; then
    NODE=$(kubectl get pod node-selector-pod -n $NAMESPACE -o jsonpath='{.spec.nodeName}')
    if [ ! -z "$NODE" ]; then
        success_msg "node-selector-pod이 노드 $NODE에 배치되었습니다."
    else
        error_msg "node-selector-pod이 스케줄링되지 않았습니다. (라벨이 맞는 노드가 없을 수 있습니다)"
        echo "팬딩 상태 확인:"
        kubectl get events -n $NAMESPACE --field-selector involvedObject.name=node-selector-pod
    fi
fi

# Node Affinity 테스트
echo ""
echo "5. Node Affinity 테스트"
echo "======================"
run_command "kubectl apply -f node-affinity.yml"

sleep 5
echo "Node Affinity Pod 배치 확인:"
kubectl get pods -n $NAMESPACE -o wide | grep affinity

# Pod Affinity/Anti-Affinity 테스트
echo ""
echo "6. Pod Affinity/Anti-Affinity 테스트"
echo "===================================="
run_command "kubectl apply -f pod-affinity.yml"

echo "Pod 배치 대기 중... (30초)"
sleep 30

echo ""
echo "Pod 배치 결과:"
kubectl get pods -n $NAMESPACE -o wide

# Anti-Affinity 검증
echo ""
echo "Anti-Affinity 검증 (Redis 인스턴스):"
redis_pods=$(kubectl get pods -n $NAMESPACE -l app=redis -o jsonpath='{.items[*].metadata.name}')
if [ ! -z "$redis_pods" ]; then
    echo "Redis Pod 노드 배치:"
    for pod in $redis_pods; do
        node=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.nodeName}')
        echo "  - $pod: $node"
    done
fi

# Taints와 Tolerations 테스트
echo ""
echo "7. Taints와 Tolerations 테스트"
echo "=============================="

# 테스트용 Taint 추가
if [ ! -z "$FIRST_NODE" ]; then
    run_command "kubectl taint nodes $FIRST_NODE special=true:NoSchedule --overwrite"
    success_msg "노드 $FIRST_NODE에 Taint 추가"
fi

run_command "kubectl apply -f taints-tolerations.yml"

sleep 10
echo "Toleration이 있는 Pod 확인:"
kubectl get pods -n $NAMESPACE -o wide | grep -E "gpu-workload|system-component|critical-app"

# Topology Spread Constraints 테스트
echo ""
echo "8. Topology Spread Constraints 테스트"
echo "====================================="
run_command "kubectl apply -f topology-spread.yml"

echo "Topology Spread 배치 대기 중... (30초)"
sleep 30

echo ""
echo "Zone Spread App 배치 결과:"
kubectl get pods -n $NAMESPACE -l app=zone-spread -o wide

# 배치 분석
echo ""
echo "9. 배치 분석"
echo "==========="

echo ""
echo "노드별 Pod 분포:"
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    count=$(kubectl get pods -n $NAMESPACE --field-selector spec.nodeName=$node -o json | jq '.items | length')
    echo "  $node: $count개 Pod"
done

echo ""
echo "앱별 Pod 분포:"
for app in redis web database api-gateway zone-spread distributed-db ha-web cache; do
    count=$(kubectl get pods -n $NAMESPACE -l app=$app --no-headers 2>/dev/null | wc -l)
    if [ $count -gt 0 ]; then
        echo "  $app: $count개 Pod"
    fi
done

# 스케줄링 이벤트 확인
echo ""
echo "10. 스케줄링 이벤트"
echo "=================="
echo "최근 스케줄링 관련 이벤트:"
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | grep -E "Scheduled|FailedScheduling|FailedAttachVolume" | tail -10

# 팬딩 Pod 확인
echo ""
echo "11. 팬딩 Pod 확인"
echo "================"
pending_pods=$(kubectl get pods -n $NAMESPACE --field-selector status.phase=Pending -o jsonpath='{.items[*].metadata.name}')
if [ ! -z "$pending_pods" ]; then
    error_msg "팬딩 상태인 Pod가 있습니다:"
    for pod in $pending_pods; do
        echo "  - $pod"
        echo "    이유:"
        kubectl describe pod $pod -n $NAMESPACE | grep -A 5 "Events:" | tail -5
    done
else
    success_msg "모든 Pod가 정상적으로 스케줄링되었습니다."
fi

# 리소스 사용량 확인
echo ""
echo "12. 리소스 사용량"
echo "================"
run_command "kubectl top nodes" || echo "Metrics Server가 설치되지 않았습니다."

# 정리 옵션
echo ""
echo "============================================"
echo "테스트 완료!"
echo "============================================"
echo ""
read -p "리소스를 정리하시겠습니까? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "리소스 정리 중..."
    
    # Taint 제거
    if [ ! -z "$FIRST_NODE" ]; then
        kubectl taint nodes $FIRST_NODE special=true:NoSchedule- 2>/dev/null || true
    fi
    
    # 네임스페이스 삭제
    kubectl delete namespace $NAMESPACE --wait=false
    success_msg "정리 완료"
else
    echo "리소스를 유지합니다."
    echo "수동으로 정리하려면 다음 명령을 실행하세요:"
    echo "  kubectl delete namespace $NAMESPACE"
    if [ ! -z "$FIRST_NODE" ]; then
        echo "  kubectl taint nodes $FIRST_NODE special=true:NoSchedule-"
    fi
fi

echo ""
echo "테스트 결과를 'test-results.txt'에 저장하려면:"
echo "  ./test-placement.sh > test-results.txt 2>&1"