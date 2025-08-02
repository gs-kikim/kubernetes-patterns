#!/bin/bash

# test-dependencies.sh
# 런타임 의존성 테스트 스크립트

set +e  # 에러가 발생해도 계속 진행

echo "=== Runtime Dependencies Test Suite ==="
echo "Starting at: $(date)"
echo

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
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

# 1. PVC 의존성 테스트
test_pvc_dependency() {
    echo -e "\n${YELLOW}=== Test 1: PVC Dependency ===${NC}"
    
    # PVC 없이 Pod 생성
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-missing-pvc
  labels:
    test: dependencies
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "30"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: non-existent-pvc
EOF

    # Pod 상태 확인
    sleep 10
    pod_status=$(kubectl get pod test-missing-pvc -o jsonpath='{.status.phase}')
    
    if [ "$pod_status" = "Pending" ]; then
        # PVC 누락으로 인한 이벤트 확인
        kubectl get events --field-selector involvedObject.name=test-missing-pvc | grep "persistentvolumeclaim"
        return 0
    else
        return 1
    fi
}

# 2. ConfigMap 의존성 및 업데이트 테스트
test_configmap_update() {
    echo -e "\n${YELLOW}=== Test 2: ConfigMap Live Update ===${NC}"
    
    # ConfigMap 생성
    kubectl create configmap test-config --from-literal=message="Initial message"
    
    # ConfigMap을 사용하는 Pod 생성
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-config-update
  labels:
    test: dependencies
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c"]
    args:
      - |
        while true; do
          echo "Config value: \$(cat /etc/config/message)"
          sleep 5
        done
    volumeMounts:
    - name: config
      mountPath: /etc/config
  volumes:
  - name: config
    configMap:
      name: test-config
EOF

    # Pod이 실행될 때까지 대기
    kubectl wait --for=condition=ready pod/test-config-update --timeout=30s
    
    # 초기 값 확인
    sleep 10
    initial_log=$(kubectl logs test-config-update | tail -1)
    echo "Initial log: $initial_log"
    
    # ConfigMap 업데이트
    kubectl patch configmap test-config -p '{"data":{"message":"Updated message"}}'
    
    # 업데이트 반영 대기 (최대 90초)
    echo "Waiting for ConfigMap update to propagate..."
    sleep 90
    
    # 업데이트된 값 확인
    kubectl logs test-config-update | tail -5
    updated_log=$(kubectl logs test-config-update | tail -1)
    echo "Updated log: $updated_log"
    
    if [[ "$updated_log" == *"Updated message"* ]]; then
        return 0
    else
        return 1
    fi
}

# 3. Secret 마운트 테스트
test_secret_mount() {
    echo -e "\n${YELLOW}=== Test 3: Secret Mount ===${NC}"
    
    # Secret 생성
    kubectl create secret generic test-secret \
        --from-literal=username=admin \
        --from-literal=password=secretpass
    
    # Secret을 사용하는 Pod 생성
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-secret-mount
  labels:
    test: dependencies
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c"]
    args:
      - |
        echo "Username: \$(cat /etc/secrets/username)"
        echo "Password exists: \$(test -f /etc/secrets/password && echo 'yes' || echo 'no')"
        echo "Password length: \$(cat /etc/secrets/password | wc -c)"
        ls -la /etc/secrets/
    volumeMounts:
    - name: secret
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret
    secret:
      secretName: test-secret
      defaultMode: 0400
EOF

    # Pod 실행 대기
    kubectl wait --for=condition=completed pod/test-secret-mount --timeout=30s || true
    
    # 로그 확인
    logs=$(kubectl logs test-secret-mount)
    
    if [[ "$logs" == *"Username: admin"* ]] && [[ "$logs" == *"Password exists: yes"* ]]; then
        # 권한 확인
        kubectl logs test-secret-mount | grep -E "^-r--"
        return 0
    else
        return 1
    fi
}

# 4. Service Discovery 테스트
test_service_discovery() {
    echo -e "\n${YELLOW}=== Test 4: Service Discovery ===${NC}"
    
    # Service 생성
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: test-service
  labels:
    test: dependencies
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: test-backend
---
apiVersion: v1
kind: Pod
metadata:
  name: test-backend
  labels:
    app: test-backend
    test: dependencies
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
EOF

    # Service 준비 대기
    sleep 10
    
    # Service Discovery 테스트 Pod
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-service-client
  labels:
    test: dependencies
spec:
  containers:
  - name: client
    image: busybox
    command: ["sh", "-c"]
    args:
      - |
        # DNS 확인
        nslookup test-service
        
        # 환경변수 확인
        env | grep TEST_SERVICE
        
        # 연결 테스트
        wget -O- -T 5 http://test-service
EOF

    # 실행 대기
    kubectl wait --for=condition=completed pod/test-service-client --timeout=30s || true
    
    # 결과 확인
    logs=$(kubectl logs test-service-client)
    
    if [[ "$logs" == *"Address"*"test-service"* ]] && [[ "$logs" == *"TEST_SERVICE_PORT"* ]]; then
        return 0
    else
        return 1
    fi
}

# 5. EmptyDir 공유 테스트
test_emptydir_sharing() {
    echo -e "\n${YELLOW}=== Test 5: EmptyDir Volume Sharing ===${NC}"
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-emptydir
  labels:
    test: dependencies
spec:
  containers:
  - name: writer
    image: busybox
    command: ["sh", "-c"]
    args:
      - |
        echo "Writer started"
        for i in \$(seq 1 5); do
          echo "Message \$i from writer" >> /shared/data.txt
          sleep 2
        done
    volumeMounts:
    - name: shared
      mountPath: /shared
  
  - name: reader
    image: busybox
    command: ["sh", "-c"]
    args:
      - |
        echo "Reader started"
        sleep 5
        while [ ! -f /shared/data.txt ]; do
          echo "Waiting for data..."
          sleep 1
        done
        echo "Reading data:"
        cat /shared/data.txt
    volumeMounts:
    - name: shared
      mountPath: /shared
  
  volumes:
  - name: shared
    emptyDir: {}
EOF

    # 실행 완료 대기
    echo "Waiting for emptyDir sharing test..."
    sleep 20
    
    # Reader 로그 확인
    reader_logs=$(kubectl logs test-emptydir -c reader 2>/dev/null || echo "")
    echo "Reader logs: $reader_logs"
    
    if [[ "$reader_logs" == *"Message"*"from writer"* ]]; then
        return 0
    else
        return 1
    fi
}

# 메인 실행
echo "Starting dependency tests..."

# 각 테스트 실행
run_test "PVC Dependency Check" test_pvc_dependency
run_test "ConfigMap Live Update" test_configmap_update
run_test "Secret Mount Permissions" test_secret_mount
run_test "Service Discovery" test_service_discovery
run_test "EmptyDir Volume Sharing" test_emptydir_sharing

# 정리
echo -e "\n${YELLOW}=== Cleanup ===${NC}"
kubectl delete pods,services,configmaps,secrets -l test=dependencies --force --grace-period=0 2>/dev/null

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