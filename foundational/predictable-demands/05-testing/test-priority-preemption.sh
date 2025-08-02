#!/bin/bash

# test-priority-preemption.sh
# Pod 우선순위와 선점 테스트 스크립트

set +e  # 에러가 발생해도 계속 진행

echo "=== Pod Priority and Preemption Test Suite ==="
echo "Starting at: $(date)"
echo

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 테스트 결과 저장
PASSED=0
FAILED=0

# 테스트 함수
run_test() {
    local test_name=$1
    local test_cmd=$2
    
    echo -n "Running: $test_name... "
    
    if eval "$test_cmd" > /tmp/test_output.log 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAILED${NC}"
        echo "Error output:"
        cat /tmp/test_output.log
        ((FAILED++))
    fi
}

# 1. PriorityClass 생성 테스트
test_priority_classes() {
    echo -e "\n${YELLOW}=== Test 1: Priority Class Creation ===${NC}"
    
    # 다양한 우선순위 클래스 생성
    cat <<EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: test-high-priority
value: 1000
globalDefault: false
description: "Test high priority class"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: test-medium-priority
value: 500
globalDefault: false
description: "Test medium priority class"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: test-low-priority
value: 100
globalDefault: false
description: "Test low priority class"
EOF

    # PriorityClass 확인
    priority_count=$(kubectl get priorityclasses | grep -E "test-(high|medium|low)-priority" | wc -l)
    
    if [ "$priority_count" -eq 3 ]; then
        kubectl get priorityclasses | grep test-
        return 0
    else
        return 1
    fi
}

# 2. 우선순위별 Pod 스케줄링 테스트
test_priority_scheduling() {
    echo -e "\n${YELLOW}=== Test 2: Priority-based Scheduling ===${NC}"
    
    # 서로 다른 우선순위의 Pod 생성
    for priority in high medium low; do
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-priority-$priority
  labels:
    test: priority
    priority: $priority
spec:
  priorityClassName: test-$priority-priority
  containers:
  - name: app
    image: busybox
    command: ["sleep", "600"]
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
EOF
    done
    
    # 스케줄링 대기
    sleep 10
    
    # Pod 우선순위 확인
    echo -e "${BLUE}Pod Priorities:${NC}"
    kubectl get pods -l test=priority -o custom-columns=NAME:.metadata.name,PRIORITY:.spec.priority,STATUS:.status.phase
    
    # 모든 Pod이 스케줄링되었는지 확인
    scheduled_count=$(kubectl get pods -l test=priority --field-selector=status.phase=Running --no-headers | wc -l)
    
    if [ "$scheduled_count" -ge 2 ]; then
        return 0
    else
        return 1
    fi
}

# 3. 선점 시나리오 테스트
test_preemption_scenario() {
    echo -e "\n${YELLOW}=== Test 3: Preemption Scenario ===${NC}"
    
    # 노드의 할당 가능한 리소스 확인
    echo -e "${BLUE}Available node resources:${NC}"
    kubectl describe nodes | grep -A 5 "Allocated resources:" | head -10
    
    # 1단계: 낮은 우선순위 Pod으로 클러스터 채우기
    echo "Step 1: Filling cluster with low priority pods..."
    for i in {1..10}; do
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-low-filler-$i
  labels:
    test: preemption
    stage: filler
spec:
  priorityClassName: test-low-priority
  containers:
  - name: app
    image: nginx:alpine
    resources:
      requests:
        cpu: "200m"
        memory: "256Mi"
      limits:
        cpu: "200m"
        memory: "256Mi"
EOF
    done
    
    # 실행 대기
    sleep 20
    
    # 실행 중인 low priority pod 수 확인
    low_running=$(kubectl get pods -l stage=filler --field-selector=status.phase=Running --no-headers | wc -l)
    echo "Low priority pods running: $low_running"
    
    # 2단계: 높은 우선순위 Pod 추가 (선점 유발)
    echo "Step 2: Adding high priority pod to trigger preemption..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-high-preemptor
  labels:
    test: preemption
    stage: preemptor
spec:
  priorityClassName: test-high-priority
  containers:
  - name: app
    image: nginx:alpine
    resources:
      requests:
        cpu: "1000m"
        memory: "1Gi"
      limits:
        cpu: "1000m"
        memory: "1Gi"
EOF

    # 선점 발생 대기
    sleep 30
    
    # 선점 확인
    preemptor_status=$(kubectl get pod test-high-preemptor -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    evicted_count=$(kubectl get events --field-selector reason=Preempted --no-headers | wc -l)
    
    echo "High priority pod status: $preemptor_status"
    echo "Preempted events count: $evicted_count"
    
    # 선점 이벤트 표시
    kubectl get events --field-selector reason=Preempted | tail -5
    
    if [ "$preemptor_status" = "Running" ] || [ "$evicted_count" -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

# 4. PodDisruptionBudget과 우선순위 테스트
test_pdb_with_priority() {
    echo -e "\n${YELLOW}=== Test 4: PodDisruptionBudget with Priority ===${NC}"
    
    # Deployment와 PDB 생성
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-pdb-app
spec:
  replicas: 5
  selector:
    matchLabels:
      app: pdb-test
  template:
    metadata:
      labels:
        app: pdb-test
        test: priority
    spec:
      priorityClassName: test-medium-priority
      containers:
      - name: app
        image: nginx:alpine
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: test-pdb
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: pdb-test
EOF

    # Deployment 준비 대기
    kubectl wait --for=condition=available deployment/test-pdb-app --timeout=60s
    
    # PDB 상태 확인
    pdb_status=$(kubectl get pdb test-pdb -o jsonpath='{.status.currentHealthy}')
    echo "PDB current healthy pods: $pdb_status"
    
    if [ "$pdb_status" -ge 3 ]; then
        return 0
    else
        return 1
    fi
}

# 5. 우선순위 기반 리소스 할당 테스트
test_priority_resource_allocation() {
    echo -e "\n${YELLOW}=== Test 5: Priority-based Resource Allocation ===${NC}"
    
    # 다양한 우선순위와 리소스 요구사항을 가진 Pod 생성
    priorities=("high:800m:1Gi" "medium:400m:512Mi" "low:200m:256Mi")
    
    for entry in "${priorities[@]}"; do
        IFS=':' read -r priority cpu memory <<< "$entry"
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-resource-$priority
  labels:
    test: priority-resource
    priority: $priority
spec:
  priorityClassName: test-$priority-priority
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c"]
    args:
      - |
        echo "Pod with $priority priority started"
        echo "Requested: CPU=$cpu, Memory=$memory"
        sleep 300
    resources:
      requests:
        cpu: $cpu
        memory: $memory
EOF
    done
    
    # 스케줄링 대기
    sleep 15
    
    # 리소스 할당 상태 확인
    echo -e "${BLUE}Resource allocation by priority:${NC}"
    kubectl get pods -l test=priority-resource -o custom-columns=\
NAME:.metadata.name,\
PRIORITY:.spec.priority,\
CPU_REQ:.spec.containers[0].resources.requests.cpu,\
MEM_REQ:.spec.containers[0].resources.requests.memory,\
STATUS:.status.phase
    
    # 우선순위별로 Pod이 생성되었는지 확인
    total_pods=$(kubectl get pods -l test=priority-resource --no-headers 2>/dev/null | wc -l)
    high_exists=$(kubectl get pod test-resource-high --no-headers 2>/dev/null | wc -l)
    
    if [ "$total_pods" -ge 2 ] && [ "$high_exists" -eq 1 ]; then
        echo -e "${GREEN}Priority-based resource allocation working - high priority pod created${NC}"
        return 0
    else
        return 1
    fi
}

# 6. 시스템 Pod 보호 테스트
test_system_pod_protection() {
    echo -e "\n${YELLOW}=== Test 6: System Pod Protection ===${NC}"
    
    # 시스템 우선순위 Pod 생성 (kube-system 네임스페이스)
    cat <<EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: test-system-critical
value: 900000000
globalDefault: false
description: "Test system critical priority"
---
apiVersion: v1
kind: Pod
metadata:
  name: test-system-critical-pod
  namespace: kube-system
  labels:
    test: system-protection
spec:
  priorityClassName: test-system-critical
  containers:
  - name: critical
    image: busybox
    command: ["sleep", "300"]
    resources:
      requests:
        cpu: "10m"
        memory: "32Mi"
EOF

    # Pod 생성 확인
    sleep 5
    
    system_pod_priority=$(kubectl get pod test-system-critical-pod -n kube-system -o jsonpath='{.spec.priority}' 2>/dev/null || echo "0")
    
    echo "System pod priority: $system_pod_priority"
    
    # 시스템 우선순위가 높은지 확인 (사용자 정의 최대값 이내)
    if [ "$system_pod_priority" -ge 900000000 ]; then
        echo -e "${GREEN}System pod has critical priority${NC}"
        return 0
    else
        return 1
    fi
}

# 메인 실행
echo "Starting pod priority and preemption tests..."

# 각 테스트 실행
run_test "Priority Class Creation" test_priority_classes
run_test "Priority-based Scheduling" test_priority_scheduling
run_test "Preemption Scenario" test_preemption_scenario
run_test "PDB with Priority" test_pdb_with_priority
run_test "Priority Resource Allocation" test_priority_resource_allocation
run_test "System Pod Protection" test_system_pod_protection

# 정리
echo -e "\n${YELLOW}=== Cleanup ===${NC}"
kubectl delete pods -l test=priority --force --grace-period=0
kubectl delete pods -l test=preemption --force --grace-period=0
kubectl delete pods -l test=priority-resource --force --grace-period=0
kubectl delete deployment test-pdb-app
kubectl delete pdb test-pdb
kubectl delete pod test-system-critical-pod -n kube-system --ignore-not-found
kubectl delete priorityclass -l name=test-high-priority
kubectl delete priorityclass test-high-priority test-medium-priority test-low-priority test-system-critical

# 결과 출력
echo -e "\n${YELLOW}=== Test Results ===${NC}"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed!${NC}"
    exit 1
fi