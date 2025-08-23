#!/bin/bash

echo "==================================="
echo "Graceful Shutdown 테스트"
echo "==================================="

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 1. 애플리케이션 빌드
echo -e "${YELLOW}1. 애플리케이션 Docker 이미지 빌드${NC}"
cd ../app
docker build -t lifecycle-demo:latest .
cd ../scripts

# 2. Deployment 생성
echo -e "${YELLOW}2. Graceful Shutdown 테스트 Deployment 생성${NC}"
kubectl apply -f ../k8s/03-graceful-shutdown.yaml
sleep 5

# 3. Pod 상태 확인
echo -e "${YELLOW}3. 초기 Pod 상태 확인${NC}"
kubectl get pods -l app=lifecycle-app
kubectl get service lifecycle-app

# 4. 부하 생성 (백그라운드)
echo -e "${YELLOW}4. 애플리케이션에 부하 생성${NC}"
SERVICE_IP=$(kubectl get service lifecycle-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "localhost")
SERVICE_PORT=$(kubectl get service lifecycle-app -o jsonpath='{.spec.ports[0].port}')

if [ "$SERVICE_IP" == "localhost" ]; then
    kubectl port-forward service/lifecycle-app 8080:8080 &
    PF_PID=$!
    sleep 2
    SERVICE_IP="localhost"
fi

echo -e "${GREEN}서비스 엔드포인트: http://$SERVICE_IP:$SERVICE_PORT${NC}"

# 부하 생성 함수
generate_load() {
    for i in {1..20}; do
        curl -s http://$SERVICE_IP:$SERVICE_PORT/ &
        sleep 0.5
    done
}

echo "부하 생성 시작..."
generate_load &

# 5. Rolling Update로 Graceful Shutdown 테스트
echo -e "${YELLOW}5. Rolling Update 중 Graceful Shutdown 동작 확인${NC}"
sleep 3

# 한 Pod의 로그 모니터링
FIRST_POD=$(kubectl get pods -l app=lifecycle-app -o jsonpath='{.items[0].metadata.name}')
echo -e "${BLUE}모니터링 Pod: $FIRST_POD${NC}"

kubectl logs -f $FIRST_POD &
LOG_PID=$!

# 이미지 업데이트로 Rolling Update 트리거
kubectl set image deployment/lifecycle-app app=lifecycle-demo:latest --record

echo "Rolling Update 진행 중..."
sleep 10

# 로그 모니터링 중지
kill $LOG_PID 2>/dev/null

# 6. SIGTERM 처리 테스트
echo -e "${YELLOW}6. SIGTERM 신호 처리 테스트${NC}"
kubectl apply -f ../k8s/03-graceful-shutdown.yaml

sleep 5

# SIGTERM 처리 확인
POD_NAME=$(kubectl get pod -l app=sigterm-demo -o jsonpath='{.metadata.name}')
echo -e "${GREEN}테스트 Pod: $POD_NAME${NC}"

# Pod 로그 모니터링 시작
kubectl logs -f $POD_NAME &
LOG_PID=$!

sleep 2

# Pod 삭제로 SIGTERM 발생
echo "Pod 삭제 시작 (SIGTERM 전송)..."
kubectl delete pod $POD_NAME

sleep 10
kill $LOG_PID 2>/dev/null

# 7. 복잡한 수명주기 시나리오 테스트
echo -e "${YELLOW}7. 복잡한 수명주기 시나리오 테스트${NC}"
kubectl get pod complex-lifecycle-demo >/dev/null 2>&1 || kubectl apply -f ../k8s/03-graceful-shutdown.yaml

sleep 10

COMPLEX_POD="complex-lifecycle-demo"
echo -e "${BLUE}복잡한 시나리오 Pod: $COMPLEX_POD${NC}"

# Init Container 완료 확인
echo "Init Container 상태:"
kubectl get pod $COMPLEX_POD -o jsonpath='{.status.initContainerStatuses[*].state}'
echo

# PostStart 완료 확인
echo "PostStart Hook 실행 확인:"
kubectl exec $COMPLEX_POD -- cat /tmp/initialized 2>/dev/null && echo "PostStart 완료!" || echo "PostStart 진행 중..."

# Pod 삭제로 전체 수명주기 확인
echo -e "${GREEN}전체 수명주기 플로우 테스트${NC}"
kubectl logs -f $COMPLEX_POD &
LOG_PID=$!

sleep 3

kubectl delete pod $COMPLEX_POD
sleep 15

kill $LOG_PID 2>/dev/null

# 8. 메트릭 수집
echo -e "${YELLOW}8. 수명주기 이벤트 메트릭${NC}"
echo "최근 이벤트:"
kubectl get events --sort-by='.lastTimestamp' | grep -E "lifecycle|SIGTERM|PreStop|PostStart" | tail -10

# 9. 스트레스 테스트
echo -e "${YELLOW}9. 동시 다발적 Pod 종료 스트레스 테스트${NC}"
read -p "스트레스 테스트를 실행하시겠습니까? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # 여러 Pod 생성
    for i in {1..5}; do
        kubectl run stress-test-$i --image=busybox:1.35 --command -- sh -c "trap 'echo SIGTERM; sleep 2; exit 0' TERM; while true; do echo running; sleep 1; done" &
    done
    
    sleep 5
    kubectl get pods | grep stress-test
    
    # 동시 삭제
    echo "모든 Pod 동시 삭제..."
    kubectl delete pods -l run=stress-test --all
    
    # 종료 과정 모니터링
    watch -n 1 "kubectl get pods | grep stress-test"
fi

# 10. 정리
echo -e "${YELLOW}10. 테스트 정리${NC}"
read -p "모든 테스트 리소스를 삭제하시겠습니까? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete deployment lifecycle-app --ignore-not-found=true
    kubectl delete service lifecycle-app --ignore-not-found=true
    kubectl delete pod sigterm-handler-demo complex-lifecycle-demo --ignore-not-found=true
    kubectl delete pods -l run=stress-test --ignore-not-found=true
    
    # Port forward 정리
    [ ! -z "$PF_PID" ] && kill $PF_PID 2>/dev/null
    
    echo -e "${GREEN}정리 완료!${NC}"
fi

echo -e "${GREEN}Graceful Shutdown 테스트 완료!${NC}"