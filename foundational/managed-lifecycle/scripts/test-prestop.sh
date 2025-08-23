#!/bin/bash

echo "==================================="
echo "PreStop Hook 테스트"
echo "==================================="

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. ConfigMap 및 Pod 생성
echo -e "${YELLOW}1. PreStop 테스트 리소스 생성 중...${NC}"
kubectl apply -f ../k8s/02-prestop-hook.yaml
sleep 5

# 2. Pod 상태 확인
echo -e "${YELLOW}2. Pod 상태 확인${NC}"
kubectl get pods -l 'app in (prestop-demo, prestop-timing, prestop-graceful)'

# 3. PreStop 타이밍 테스트
echo -e "${YELLOW}3. PreStop과 SIGTERM 타이밍 테스트${NC}"
echo "prestop-timing-test Pod를 삭제하여 PreStop → SIGTERM 순서 확인"

# 별도 터미널에서 로그 모니터링 시작
kubectl logs -f prestop-timing-test &
LOG_PID=$!

sleep 2

# Pod 삭제 시작
echo -e "${GREEN}Pod 삭제 시작...${NC}"
kubectl delete pod prestop-timing-test

# 로그 프로세스 종료
sleep 10
kill $LOG_PID 2>/dev/null

# 4. Grace Period 테스트
echo -e "${YELLOW}4. terminationGracePeriodSeconds 테스트${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: grace-period-test
spec:
  terminationGracePeriodSeconds: 10  # 짧은 grace period
  containers:
  - name: app
    image: busybox:1.35
    command: ["/bin/sh"]
    args:
    - -c
    - |
      trap 'echo "SIGTERM 수신: \$(date)"; sleep 15; echo "종료: \$(date)"' TERM
      echo "시작: \$(date)"
      while true; do sleep 1; done
    lifecycle:
      preStop:
        exec:
          command:
          - /bin/sh
          - -c
          - |
            echo "PreStop 시작: \$(date)"
            sleep 8  # Grace period에 가까운 시간
            echo "PreStop 완료: \$(date)"
EOF

sleep 3

echo -e "${GREEN}Grace period 테스트 - Pod 삭제${NC}"
kubectl logs -f grace-period-test &
LOG_PID=$!

sleep 2
kubectl delete pod grace-period-test

sleep 15
kill $LOG_PID 2>/dev/null

# 5. PreStop 실패 시나리오
echo -e "${YELLOW}5. PreStop 실패 시나리오 테스트${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: prestop-fail-test
spec:
  terminationGracePeriodSeconds: 20
  containers:
  - name: app
    image: nginx:alpine
    lifecycle:
      preStop:
        exec:
          command:
          - /bin/sh
          - -c
          - |
            echo "PreStop 시작: 의도적 실패"
            exit 1  # PreStop 실패
EOF

sleep 3

echo -e "${RED}PreStop 실패 시 동작 확인${NC}"
kubectl delete pod prestop-fail-test &
sleep 2
kubectl get pod prestop-fail-test
kubectl describe pod prestop-fail-test | grep -A 5 "Events:"

# 6. 복잡한 PreStop 시나리오
echo -e "${YELLOW}6. 복잡한 정리 작업 시나리오${NC}"
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: complex-prestop
spec:
  terminationGracePeriodSeconds: 60
  containers:
  - name: web
    image: nginx:alpine
    lifecycle:
      preStop:
        exec:
          command:
          - /bin/sh
          - -c
          - |
            echo "[PreStop] 복잡한 정리 작업 시작: \$(date)"
            
            # 1. 활성 연결 확인
            echo "[PreStop] 활성 연결 확인..."
            netstat -an | grep ESTABLISHED | wc -l
            
            # 2. 캐시 정리
            echo "[PreStop] 캐시 데이터 정리..."
            sleep 3
            
            # 3. 로그 백업
            echo "[PreStop] 로그 백업..."
            cp -r /var/log/nginx /tmp/nginx-backup-\$(date +%s)
            
            # 4. Graceful nginx shutdown
            echo "[PreStop] Nginx graceful shutdown..."
            nginx -s quit
            
            echo "[PreStop] 정리 완료: \$(date)"
EOF

sleep 5

echo -e "${GREEN}복잡한 PreStop 실행 확인${NC}"
kubectl exec complex-prestop -- sh -c "ps aux | grep nginx"

# Pod 삭제하여 PreStop 실행
kubectl delete pod complex-prestop --wait=false
sleep 2
kubectl get pod complex-prestop

# 7. 모든 테스트 Pod 상태 요약
echo -e "${YELLOW}7. 테스트 결과 요약${NC}"
kubectl get pods --show-labels | grep -E "prestop|grace-period"

# 8. 정리
echo -e "${YELLOW}8. 테스트 정리${NC}"
read -p "모든 테스트 리소스를 삭제하시겠습니까? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete pod prestop-demo prestop-timing-test prestop-graceful-demo --ignore-not-found=true
    kubectl delete pod grace-period-test prestop-fail-test complex-prestop --ignore-not-found=true
    kubectl delete configmap prestop-scripts --ignore-not-found=true
    echo -e "${GREEN}정리 완료!${NC}"
fi

echo -e "${GREEN}PreStop Hook 테스트 완료!${NC}"