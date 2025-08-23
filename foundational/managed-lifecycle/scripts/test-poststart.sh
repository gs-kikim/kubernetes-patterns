#!/bin/bash

echo "==================================="
echo "PostStart Hook 테스트"
echo "==================================="

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. ConfigMap 생성
echo -e "${YELLOW}1. ConfigMap 생성 중...${NC}"
kubectl apply -f ../k8s/01-poststart-hook.yaml
sleep 2

# 2. PostStart 동작 확인
echo -e "${YELLOW}2. PostStart Hook 동작 테스트${NC}"
echo "   - PostStart와 메인 컨테이너의 비동기 실행 확인"

# Pod 상태 확인
kubectl get pod poststart-demo -o wide
kubectl get pod poststart-async-test -o wide

# 3. 로그 확인
echo -e "${YELLOW}3. PostStart 실행 로그 확인${NC}"
echo -e "${GREEN}poststart-demo Pod 로그:${NC}"
kubectl logs poststart-demo --tail=20

echo -e "${GREEN}poststart-async-test Pod 로그:${NC}"
kubectl logs poststart-async-test --tail=20

# 4. PostStart 실행 타이밍 확인
echo -e "${YELLOW}4. PostStart 타이밍 분석${NC}"
kubectl exec poststart-async-test -- sh -c "echo '=== Main 로그 ==='; cat /shared/main.log; echo ''; echo '=== PostStart 로그 ==='; cat /shared/poststart.log"

# 5. Pod 이벤트 확인
echo -e "${YELLOW}5. Pod 이벤트 확인${NC}"
kubectl describe pod poststart-demo | grep -A 5 "Events:"
kubectl describe pod poststart-async-test | grep -A 5 "Events:"

# 6. PostStart 실패 시나리오 테스트
echo -e "${YELLOW}6. PostStart 실패 시나리오 테스트${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: poststart-fail-test
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["sleep", "3600"]
    lifecycle:
      postStart:
        exec:
          command:
          - /bin/sh
          - -c
          - |
            echo "PostStart 시작: 의도적 실패 시나리오"
            exit 1  # 의도적 실패
EOF

sleep 5

echo -e "${RED}PostStart 실패 시 Pod 상태:${NC}"
kubectl get pod poststart-fail-test
kubectl describe pod poststart-fail-test | grep -A 10 "Events:"

# 7. 정리
echo -e "${YELLOW}7. 테스트 정리${NC}"
read -p "테스트 Pod들을 삭제하시겠습니까? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete pod poststart-demo poststart-async-test poststart-fail-test --ignore-not-found=true
    kubectl delete configmap app-config --ignore-not-found=true
    echo -e "${GREEN}정리 완료!${NC}"
fi

echo -e "${GREEN}PostStart Hook 테스트 완료!${NC}"