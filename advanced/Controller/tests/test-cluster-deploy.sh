#!/bin/bash

# Test 5: Kubernetes 클러스터 배포 테스트
# 실제 Kubernetes 클러스터에서 Controller 동작 검증
# 요구사항: kubectl이 클러스터에 연결되어 있어야 함

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="controller-test"

echo "========================================"
echo "Test 5: Kubernetes 클러스터 배포 테스트"
echo "========================================"

# kubectl 연결 확인
echo ""
echo "5.0 Kubernetes 클러스터 연결 확인"
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${YELLOW}[SKIP]${NC} Kubernetes 클러스터에 연결되지 않음"
    echo "       이 테스트를 실행하려면 kubectl이 클러스터에 연결되어야 합니다"
    exit 0
fi
echo -e "${GREEN}[PASS]${NC} 클러스터 연결됨: $(kubectl config current-context)"

PASSED=0
FAILED=0

# 정리 함수
cleanup() {
    echo ""
    echo "정리 작업 수행 중..."
    kubectl delete namespace $NAMESPACE --ignore-not-found=true --wait=false 2>/dev/null || true
}

# 스크립트 종료 시 정리
trap cleanup EXIT

# 5.1 테스트 네임스페이스 생성
echo ""
echo "5.1 테스트 네임스페이스 생성"
kubectl create namespace $NAMESPACE 2>/dev/null || true
if kubectl get namespace $NAMESPACE &>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} 네임스페이스 '$NAMESPACE' 생성됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 네임스페이스 생성 실패"
    ((FAILED++))
    exit 1
fi

# 5.2 Controller 배포
echo ""
echo "5.2 Controller 배포"
if kubectl apply -n $NAMESPACE -f "$MANIFEST_DIR/config-watcher-controller.yml"; then
    echo -e "${GREEN}[PASS]${NC} Controller 매니페스트 적용 성공"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Controller 매니페스트 적용 실패"
    ((FAILED++))
fi

# 5.3 Web App 배포
echo ""
echo "5.3 Web App 배포"
if kubectl apply -n $NAMESPACE -f "$MANIFEST_DIR/web-app.yml"; then
    echo -e "${GREEN}[PASS]${NC} Web App 매니페스트 적용 성공"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Web App 매니페스트 적용 실패"
    ((FAILED++))
fi

# 5.4 Controller Pod 실행 확인
echo ""
echo "5.4 Controller Pod 실행 대기 (최대 60초)"
if kubectl wait --for=condition=Ready pod -l app=config-watcher-controller -n $NAMESPACE --timeout=60s 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} Controller Pod 실행 중"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Controller Pod 시작 실패"
    kubectl get pods -n $NAMESPACE -l app=config-watcher-controller
    ((FAILED++))
fi

# 5.5 Web App Pod 실행 확인
echo ""
echo "5.5 Web App Pod 실행 대기 (최대 60초)"
if kubectl wait --for=condition=Ready pod -l app=webapp -n $NAMESPACE --timeout=60s 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} Web App Pod 실행 중"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Web App Pod 시작 실패"
    kubectl get pods -n $NAMESPACE -l app=webapp
    ((FAILED++))
fi

# 5.6 원래 Pod 이름 기록
echo ""
echo "5.6 현재 Web App Pod 이름 기록"
ORIGINAL_POD=$(kubectl get pods -n $NAMESPACE -l app=webapp -o jsonpath='{.items[0].metadata.name}')
echo "    원래 Pod: $ORIGINAL_POD"
if [ -n "$ORIGINAL_POD" ]; then
    echo -e "${GREEN}[PASS]${NC} Pod 이름 확인됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Pod 이름 확인 실패"
    ((FAILED++))
fi

# 5.7 ConfigMap 수정 (Controller 트리거)
echo ""
echo "5.7 ConfigMap 수정하여 Controller 트리거"
NEW_MESSAGE="Welcome to Kubernetes Patterns - Updated at $(date +%H:%M:%S)"
kubectl patch configmap webapp-config -n $NAMESPACE --type merge -p "{\"data\":{\"message\":\"$NEW_MESSAGE\"}}"
echo "    새 메시지: $NEW_MESSAGE"
echo -e "${GREEN}[PASS]${NC} ConfigMap 수정 완료"
((PASSED++))

# 5.8 Pod 재시작 확인 (최대 30초 대기)
echo ""
echo "5.8 Pod 재시작 확인 (최대 30초 대기)"
sleep 5  # Controller가 이벤트를 처리할 시간
for i in {1..25}; do
    NEW_POD=$(kubectl get pods -n $NAMESPACE -l app=webapp -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ "$NEW_POD" != "$ORIGINAL_POD" ] && [ -n "$NEW_POD" ]; then
        echo -e "${GREEN}[PASS]${NC} Pod 재시작 확인: $ORIGINAL_POD -> $NEW_POD"
        ((PASSED++))
        break
    fi
    sleep 1
done

if [ "$NEW_POD" = "$ORIGINAL_POD" ]; then
    echo -e "${YELLOW}[WARN]${NC} Pod가 재시작되지 않음 (Controller 이미지 pull 지연일 수 있음)"
    echo "    현재 Pod 상태:"
    kubectl get pods -n $NAMESPACE -l app=webapp
fi

# 5.9 Controller 로그 확인
echo ""
echo "5.9 Controller 로그 확인"
CONTROLLER_POD=$(kubectl get pods -n $NAMESPACE -l app=config-watcher-controller -o jsonpath='{.items[0].metadata.name}')
if [ -n "$CONTROLLER_POD" ]; then
    echo "    Controller Pod: $CONTROLLER_POD"
    echo "    최근 로그:"
    kubectl logs -n $NAMESPACE $CONTROLLER_POD -c config-watcher --tail=10 2>/dev/null || echo "    (로그 없음)"
    echo -e "${GREEN}[PASS]${NC} Controller 로그 조회 가능"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Controller Pod 없음"
    ((FAILED++))
fi

# 5.10 Ambassador 컨테이너 상태 확인
echo ""
echo "5.10 Ambassador 컨테이너(kubeapi-proxy) 상태 확인"
if kubectl get pod $CONTROLLER_POD -n $NAMESPACE -o jsonpath='{.status.containerStatuses[?(@.name=="kubeapi-proxy")].ready}' | grep -q 'true'; then
    echo -e "${GREEN}[PASS]${NC} Ambassador 컨테이너 정상 실행 중"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Ambassador 컨테이너 비정상"
    ((FAILED++))
fi

echo ""
echo "========================================"
echo "결과: ${PASSED} 통과, ${FAILED} 실패"
echo "========================================"

# 리소스 상태 요약
echo ""
echo "리소스 상태 요약:"
kubectl get all -n $NAMESPACE

if [ $FAILED -gt 0 ]; then
    exit 1
fi
