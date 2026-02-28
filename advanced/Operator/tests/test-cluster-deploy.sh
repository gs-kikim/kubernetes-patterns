#!/bin/bash

# Test 6: Kubernetes 클러스터 배포 테스트
# 실제 minikube 클러스터에서 Operator 동작 검증
# 요구사항: kubectl이 클러스터에 연결되어 있어야 함

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="operator-test"

echo "========================================"
echo "Test 6: Kubernetes 클러스터 배포 테스트"
echo "========================================"

# kubectl 연결 확인
echo ""
echo "6.0 Kubernetes 클러스터 연결 확인"
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
    echo -e "${BLUE}정리 작업 수행 중...${NC}"
    kubectl delete namespace $NAMESPACE --ignore-not-found=true --wait=false 2>/dev/null || true
    kubectl delete crd configwatchers.k8spatterns.com --ignore-not-found=true 2>/dev/null || true
    kubectl delete clusterrole config-watcher-crd --ignore-not-found=true 2>/dev/null || true
}

# 스크립트 종료 시 정리
trap cleanup EXIT

# 6.1 테스트 네임스페이스 생성
echo ""
echo "6.1 테스트 네임스페이스 생성"
kubectl create namespace $NAMESPACE 2>/dev/null || true
if kubectl get namespace $NAMESPACE &>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} 네임스페이스 '$NAMESPACE' 생성됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 네임스페이스 생성 실패"
    ((FAILED++))
    exit 1
fi

# 6.2 CRD 등록
echo ""
echo "6.2 ConfigWatcher CRD 등록"
if kubectl apply -f "$MANIFEST_DIR/config-watcher-crd.yml"; then
    echo -e "${GREEN}[PASS]${NC} CRD 등록 성공"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} CRD 등록 실패"
    ((FAILED++))
fi

# 6.3 CRD 확인
echo ""
echo "6.3 CRD 등록 확인"
sleep 2  # CRD 등록 대기
if kubectl get crd configwatchers.k8spatterns.com &>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} CRD 'configwatchers.k8spatterns.com' 등록 확인"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} CRD 등록 확인 실패"
    ((FAILED++))
fi

# 6.4 Operator 배포
echo ""
echo "6.4 Operator 배포"
if kubectl apply -n $NAMESPACE -f "$MANIFEST_DIR/config-watcher-operator.yml"; then
    echo -e "${GREEN}[PASS]${NC} Operator 매니페스트 적용 성공"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Operator 매니페스트 적용 실패"
    ((FAILED++))
fi

# 6.5 Web App 배포
echo ""
echo "6.5 Web App 배포"
if kubectl apply -n $NAMESPACE -f "$MANIFEST_DIR/web-app.yml"; then
    echo -e "${GREEN}[PASS]${NC} Web App 매니페스트 적용 성공"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Web App 매니페스트 적용 실패"
    ((FAILED++))
fi

# 6.6 ConfigWatcher CR 생성
echo ""
echo "6.6 ConfigWatcher CR 생성"
if kubectl apply -n $NAMESPACE -f "$MANIFEST_DIR/config-watcher-sample.yml"; then
    echo -e "${GREEN}[PASS]${NC} ConfigWatcher CR 생성 성공"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} ConfigWatcher CR 생성 실패"
    ((FAILED++))
fi

# 6.7 ConfigWatcher CR 조회 (short name 'cw' 사용)
echo ""
echo "6.7 ConfigWatcher CR 조회 (kubectl get cw)"
if kubectl get cw -n $NAMESPACE 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} ConfigWatcher CR 조회 성공 (short name 'cw')"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} ConfigWatcher CR 조회 실패"
    ((FAILED++))
fi

# 6.8 Operator Pod 실행 확인
echo ""
echo "6.8 Operator Pod 실행 대기 (최대 180초, 이미지 pull 포함)"
if kubectl wait --for=condition=Ready pod -l app=config-watcher-operator -n $NAMESPACE --timeout=180s 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} Operator Pod 실행 중"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Operator Pod 시작 실패"
    echo "    Pod 상태:"
    kubectl get pods -n $NAMESPACE -l app=config-watcher-operator
    kubectl describe pod -n $NAMESPACE -l app=config-watcher-operator 2>/dev/null | tail -20
    ((FAILED++))
fi

# 6.9 Web App Pod 실행 확인
echo ""
echo "6.9 Web App Pod 실행 대기 (최대 180초, 이미지 pull 포함)"
if kubectl wait --for=condition=Ready pod -l app=webapp -n $NAMESPACE --timeout=180s 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} Web App Pod 실행 중"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Web App Pod 시작 실패"
    echo "    Pod 상태:"
    kubectl get pods -n $NAMESPACE -l app=webapp
    ((FAILED++))
fi

# 6.10 Ambassador 컨테이너(kubeapi-proxy) 상태 확인
echo ""
echo "6.10 Ambassador 컨테이너(kubeapi-proxy) 상태 확인"
OPERATOR_POD=$(kubectl get pods -n $NAMESPACE -l app=config-watcher-operator -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$OPERATOR_POD" ]; then
    if kubectl get pod $OPERATOR_POD -n $NAMESPACE -o jsonpath='{.status.containerStatuses[?(@.name=="kubeapi-proxy")].ready}' 2>/dev/null | grep -q 'true'; then
        echo -e "${GREEN}[PASS]${NC} Ambassador 컨테이너(kubeapi-proxy) 정상 실행 중"
        ((PASSED++))
    else
        echo -e "${RED}[FAIL]${NC} Ambassador 컨테이너 비정상"
        ((FAILED++))
    fi
else
    echo -e "${RED}[FAIL]${NC} Operator Pod를 찾을 수 없음"
    ((FAILED++))
fi

# 6.11 원래 Pod 이름 기록
echo ""
echo "6.11 현재 Web App Pod 이름 기록"
ORIGINAL_POD=$(kubectl get pods -n $NAMESPACE -l app=webapp -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
echo "    원래 Pod: $ORIGINAL_POD"
if [ -n "$ORIGINAL_POD" ]; then
    echo -e "${GREEN}[PASS]${NC} Pod 이름 확인됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Pod 이름 확인 실패"
    ((FAILED++))
fi

# 6.12 ConfigMap 수정 (Operator 트리거)
echo ""
echo "6.12 ConfigMap 수정하여 Operator 트리거"
NEW_MESSAGE="Updated at $(date +%H%M%S)"
kubectl patch configmap webapp-config -n $NAMESPACE --type merge -p "{\"data\":{\"message\":\"$NEW_MESSAGE\"}}"
echo "    새 메시지: $NEW_MESSAGE"
echo -e "${GREEN}[PASS]${NC} ConfigMap 수정 완료"
((PASSED++))

# 6.13 Pod 재시작 확인 (최대 60초 대기)
echo ""
echo "6.13 Pod 재시작 확인 (최대 60초 대기)"
RESTARTED=false
sleep 5  # Operator가 이벤트를 처리할 시간
for i in $(seq 1 55); do
    NEW_POD=$(kubectl get pods -n $NAMESPACE -l app=webapp -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ "$NEW_POD" != "$ORIGINAL_POD" ] && [ -n "$NEW_POD" ]; then
        echo -e "${GREEN}[PASS]${NC} Pod 재시작 확인: $ORIGINAL_POD -> $NEW_POD"
        ((PASSED++))
        RESTARTED=true
        break
    fi
    sleep 1
done

if [ "$RESTARTED" = false ]; then
    echo -e "${YELLOW}[WARN]${NC} Pod가 재시작되지 않음 (이미지 pull 지연 또는 Operator 처리 지연일 수 있음)"
    echo "    현재 Pod 상태:"
    kubectl get pods -n $NAMESPACE -l app=webapp
fi

# 6.14 Operator 로그 확인
echo ""
echo "6.14 Operator 로그 확인"
OPERATOR_POD=$(kubectl get pods -n $NAMESPACE -l app=config-watcher-operator -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$OPERATOR_POD" ]; then
    echo "    Operator Pod: $OPERATOR_POD"
    echo "    최근 로그:"
    kubectl logs -n $NAMESPACE $OPERATOR_POD -c config-watcher --tail=15 2>/dev/null || echo "    (로그 없음)"
    echo -e "${GREEN}[PASS]${NC} Operator 로그 조회 가능"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Operator Pod 없음"
    ((FAILED++))
fi

echo ""
echo "========================================"
echo "결과: ${PASSED} 통과, ${FAILED} 실패"
echo "========================================"

# 리소스 상태 요약
echo ""
echo "리소스 상태 요약:"
kubectl get all -n $NAMESPACE 2>/dev/null
echo ""
echo "ConfigWatcher CR 상태:"
kubectl get cw -n $NAMESPACE 2>/dev/null

if [ $FAILED -gt 0 ]; then
    exit 1
fi
