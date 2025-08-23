#!/bin/bash

echo "==================================="
echo "완전한 수명주기 통합 테스트"
echo "==================================="

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 테스트 결과 저장
TEST_RESULTS=()

# 테스트 함수
run_test() {
    local test_name=$1
    local test_command=$2
    
    echo -e "${YELLOW}테스트: $test_name${NC}"
    if eval $test_command; then
        echo -e "${GREEN}✓ 성공${NC}"
        TEST_RESULTS+=("✓ $test_name")
        return 0
    else
        echo -e "${RED}✗ 실패${NC}"
        TEST_RESULTS+=("✗ $test_name")
        return 1
    fi
}

# 1. 리소스 생성
echo -e "${PURPLE}=== 1단계: 리소스 생성 ===${NC}"
kubectl apply -f ../k8s/04-complete-lifecycle.yaml
sleep 5

# 2. Init Container 테스트
echo -e "${PURPLE}=== 2단계: Init Container 실행 확인 ===${NC}"
POD_NAME="complete-lifecycle"

run_test "Init Container 완료" \
    "kubectl get pod $POD_NAME -o jsonpath='{.status.initContainerStatuses[0].state.terminated.reason}' | grep -q 'Completed'"

# 3. PostStart Hook 테스트
echo -e "${PURPLE}=== 3단계: PostStart Hook 실행 확인 ===${NC}"
sleep 5

run_test "PostStart 초기화 파일 생성" \
    "kubectl exec $POD_NAME -- test -f /tmp/ready"

run_test "PostStart 로그 확인" \
    "kubectl exec $POD_NAME -- grep -q 'PostStart' /tmp/poststart.log 2>/dev/null"

# 4. Health Probes 테스트
echo -e "${PURPLE}=== 4단계: Health Probes 동작 확인 ===${NC}"

run_test "Liveness Probe 정상" \
    "kubectl get pod $POD_NAME -o jsonpath='{.status.containerStatuses[0].ready}' | grep -q 'true'"

run_test "Readiness Probe 정상" \
    "kubectl describe pod $POD_NAME | grep -q 'Liveness:.*exec.*succeeded'"

# 5. 메인 애플리케이션 동작 확인
echo -e "${PURPLE}=== 5단계: 메인 애플리케이션 동작 확인 ===${NC}"

echo -e "${BLUE}애플리케이션 로그 (최근 5줄):${NC}"
kubectl logs $POD_NAME --tail=5

run_test "애플리케이션 실행 중" \
    "kubectl logs $POD_NAME | grep -q '정상 운영 중'"

# 6. PreStop Hook 테스트
echo -e "${PURPLE}=== 6단계: PreStop Hook 및 SIGTERM 처리 테스트 ===${NC}"

echo "Pod 삭제 시작 (PreStop → SIGTERM 순서 확인)..."

# 로그 스트리밍 백그라운드 시작
{
    kubectl logs -f $POD_NAME 2>/dev/null | while IFS= read -r line; do
        if echo "$line" | grep -q "PreStop"; then
            echo -e "${YELLOW}[PreStop] $line${NC}"
        elif echo "$line" | grep -q "SIGTERM"; then
            echo -e "${RED}[SIGTERM] $line${NC}"
        else
            echo "$line"
        fi
    done
} &
LOG_PID=$!

# Pod 삭제
kubectl delete pod $POD_NAME --wait=false

# 종료 과정 모니터링
echo -e "${BLUE}종료 과정 모니터링:${NC}"
for i in {1..15}; do
    STATUS=$(kubectl get pod $POD_NAME -o jsonpath='{.status.phase}' 2>/dev/null)
    if [ -z "$STATUS" ]; then
        echo "Pod 삭제 완료"
        break
    fi
    echo "상태 [$i/15]: $STATUS"
    sleep 1
done

kill $LOG_PID 2>/dev/null

# 7. Job 수명주기 테스트
echo -e "${PURPLE}=== 7단계: Job 수명주기 테스트 ===${NC}"

JOB_NAME="lifecycle-job"
echo "Job 실행 모니터링..."

# Job 완료 대기
for i in {1..30}; do
    JOB_STATUS=$(kubectl get job $JOB_NAME -o jsonpath='{.status.conditions[0].type}' 2>/dev/null)
    if [ "$JOB_STATUS" == "Complete" ]; then
        echo -e "${GREEN}Job 완료!${NC}"
        break
    fi
    echo "Job 진행 중... [$i/30]"
    sleep 2
done

run_test "Job 성공적 완료" \
    "kubectl get job $JOB_NAME -o jsonpath='{.status.succeeded}' | grep -q '1'"

# Job Pod 로그 확인
JOB_POD=$(kubectl get pods -l app=lifecycle-job -o jsonpath='{.items[0].metadata.name}')
echo -e "${BLUE}Job Pod 로그:${NC}"
kubectl logs $JOB_POD --tail=10

# 8. 복잡한 시나리오 테스트
echo -e "${PURPLE}=== 8단계: 복잡한 시나리오 통합 테스트 ===${NC}"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: scenario-test
spec:
  terminationGracePeriodSeconds: 45
  initContainers:
  - name: init
    image: busybox:1.35
    command: ['sh', '-c', 'echo "Init 실행"; sleep 2']
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      trap 'echo "SIGTERM 처리"; sleep 3; exit 0' TERM
      echo "앱 시작"
      while [ ! -f /tmp/initialized ]; do sleep 1; done
      echo "앱 준비 완료"
      while true; do
        echo "실행 중: \$(date)"
        sleep 3
      done
    lifecycle:
      postStart:
        exec:
          command: ['sh', '-c', 'sleep 3; touch /tmp/initialized; echo "PostStart 완료"']
      preStop:
        exec:
          command: ['sh', '-c', 'echo "PreStop 시작"; sleep 5; echo "PreStop 완료"']
    livenessProbe:
      exec:
        command: ['test', '-f', '/tmp/initialized']
      initialDelaySeconds: 5
      periodSeconds: 3
EOF

sleep 10

run_test "복잡한 시나리오 Pod 실행" \
    "kubectl get pod scenario-test -o jsonpath='{.status.phase}' | grep -q 'Running'"

# 9. 이벤트 분석
echo -e "${PURPLE}=== 9단계: 수명주기 이벤트 분석 ===${NC}"

echo -e "${BLUE}수명주기 관련 이벤트:${NC}"
kubectl get events --sort-by='.lastTimestamp' | grep -E "lifecycle|PostStart|PreStop|SIGTERM|Init" | tail -10

# 10. 테스트 결과 요약
echo -e "${PURPLE}=== 테스트 결과 요약 ===${NC}"
echo -e "${BLUE}실행된 테스트:${NC}"
for result in "${TEST_RESULTS[@]}"; do
    if [[ $result == *"✓"* ]]; then
        echo -e "${GREEN}$result${NC}"
    else
        echo -e "${RED}$result${NC}"
    fi
done

# 성공/실패 카운트
SUCCESS_COUNT=$(printf '%s\n' "${TEST_RESULTS[@]}" | grep -c "✓")
FAIL_COUNT=$(printf '%s\n' "${TEST_RESULTS[@]}" | grep -c "✗")

echo
echo -e "${BLUE}총 테스트: $((SUCCESS_COUNT + FAIL_COUNT))${NC}"
echo -e "${GREEN}성공: $SUCCESS_COUNT${NC}"
echo -e "${RED}실패: $FAIL_COUNT${NC}"

# 11. 정리
echo -e "${YELLOW}테스트 리소스 정리${NC}"
read -p "모든 테스트 리소스를 삭제하시겠습니까? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete pod complete-lifecycle scenario-test --ignore-not-found=true
    kubectl delete job lifecycle-job --ignore-not-found=true
    kubectl delete configmap lifecycle-scripts --ignore-not-found=true
    echo -e "${GREEN}정리 완료!${NC}"
fi

echo -e "${GREEN}완전한 수명주기 통합 테스트 완료!${NC}"