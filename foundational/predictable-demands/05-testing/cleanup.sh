#!/bin/bash

# cleanup.sh
# 테스트 환경 정리 스크립트

set +e  # 에러가 발생해도 계속 진행

echo "=== Cleanup Script for Predictable Demands Tests ==="
echo "Starting cleanup at: $(date)"
echo

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 정리 함수
cleanup_resources() {
    local resource_type=$1
    local label_selector=$2
    local namespace=$3
    
    if [ -z "$namespace" ]; then
        echo -n "Cleaning up $resource_type... "
        kubectl delete $resource_type -l "$label_selector" --all-namespaces --force --grace-period=0 2>/dev/null
    else
        echo -n "Cleaning up $resource_type in namespace $namespace... "
        kubectl delete $resource_type -l "$label_selector" -n "$namespace" --force --grace-period=0 2>/dev/null
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Done${NC}"
    else
        echo -e "${YELLOW}Nothing to clean or already cleaned${NC}"
    fi
}

echo -e "${YELLOW}Step 1: Cleaning up test Pods${NC}"
# 테스트 라벨이 있는 모든 Pod 삭제
kubectl delete pods -l test=dependencies --all-namespaces --force --grace-period=0 2>/dev/null
kubectl delete pods -l test=resource-limits --all-namespaces --force --grace-period=0 2>/dev/null
kubectl delete pods -l test=priority --all-namespaces --force --grace-period=0 2>/dev/null
kubectl delete pods -l test=preemption --all-namespaces --force --grace-period=0 2>/dev/null
kubectl delete pods -l test=priority-resource --all-namespaces --force --grace-period=0 2>/dev/null
kubectl delete pods -l test=system-protection -n kube-system --force --grace-period=0 2>/dev/null

# 특정 이름 패턴의 Pod 삭제
echo "Cleaning up pods by name pattern..."
kubectl delete pods --all-namespaces --field-selector=metadata.name=~test- --force --grace-period=0 2>/dev/null

echo -e "\n${YELLOW}Step 2: Cleaning up Deployments and ReplicaSets${NC}"
kubectl delete deployments -l test --all-namespaces --force --grace-period=0 2>/dev/null
kubectl delete replicasets -l test --all-namespaces --force --grace-period=0 2>/dev/null

echo -e "\n${YELLOW}Step 3: Cleaning up Services${NC}"
kubectl delete services -l test=dependencies --all-namespaces 2>/dev/null

echo -e "\n${YELLOW}Step 4: Cleaning up ConfigMaps and Secrets${NC}"
kubectl delete configmaps -l test --all-namespaces 2>/dev/null
kubectl delete secrets -l test --all-namespaces 2>/dev/null
# 특정 이름 패턴의 ConfigMap/Secret 삭제
kubectl delete configmaps --all-namespaces --field-selector=metadata.name=~test- 2>/dev/null
kubectl delete secrets --all-namespaces --field-selector=metadata.name=~test- 2>/dev/null

echo -e "\n${YELLOW}Step 5: Cleaning up PVCs and PVs${NC}"
kubectl delete pvc -l test --all-namespaces 2>/dev/null
kubectl delete pv -l test 2>/dev/null

echo -e "\n${YELLOW}Step 6: Cleaning up Jobs and CronJobs${NC}"
kubectl delete jobs -l test --all-namespaces --force --grace-period=0 2>/dev/null
kubectl delete cronjobs -l test --all-namespaces 2>/dev/null

echo -e "\n${YELLOW}Step 7: Cleaning up PriorityClasses${NC}"
kubectl delete priorityclass test-high-priority test-medium-priority test-low-priority test-system-critical 2>/dev/null

echo -e "\n${YELLOW}Step 8: Cleaning up PodDisruptionBudgets${NC}"
kubectl delete pdb test-pdb --all-namespaces 2>/dev/null

echo -e "\n${YELLOW}Step 9: Cleaning up test namespaces${NC}"
# 테스트용 네임스페이스 삭제
for ns in test-quotas test-combined test-priority test-resources; do
    echo -n "Deleting namespace $ns... "
    if kubectl delete namespace $ns 2>/dev/null; then
        echo -e "${GREEN}Done${NC}"
    else
        echo -e "${YELLOW}Not found or already deleted${NC}"
    fi
done

echo -e "\n${YELLOW}Step 10: Cleaning up ResourceQuotas and LimitRanges${NC}"
# 기본 네임스페이스의 테스트 ResourceQuota/LimitRange 삭제
kubectl delete resourcequota --all-namespaces --field-selector=metadata.name=~test- 2>/dev/null
kubectl delete limitrange --all-namespaces --field-selector=metadata.name=~test- 2>/dev/null

echo -e "\n${YELLOW}Step 11: Final verification${NC}"
echo "Checking for remaining test resources..."

# 남은 테스트 리소스 확인
remaining_pods=$(kubectl get pods --all-namespaces -o json | jq '.items[] | select(.metadata.name | startswith("test-")) | .metadata.name' | wc -l)
remaining_ns=$(kubectl get namespaces -o json | jq '.items[] | select(.metadata.name | startswith("test-")) | .metadata.name' | wc -l)

if [ "$remaining_pods" -eq 0 ] && [ "$remaining_ns" -eq 0 ]; then
    echo -e "${GREEN}✓ All test resources cleaned successfully${NC}"
else
    echo -e "${YELLOW}⚠ Some test resources may still remain:${NC}"
    if [ "$remaining_pods" -gt 0 ]; then
        echo "  - $remaining_pods test pods still exist"
        kubectl get pods --all-namespaces | grep test-
    fi
    if [ "$remaining_ns" -gt 0 ]; then
        echo "  - $remaining_ns test namespaces still exist"
        kubectl get namespaces | grep test-
    fi
fi

echo -e "\n${GREEN}Cleanup completed at: $(date)${NC}"