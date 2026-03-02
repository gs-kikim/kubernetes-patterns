#!/bin/bash

# Test 4: Kubernetes 클러스터 배포 테스트 (minikube)
# ImageBuilder 패턴의 이미지 빌드 및 실행을 실제 클러스터에서 검증
# 요구사항: minikube + registry addon

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="imagebuilder-test"

echo "========================================"
echo "Test 4: Kubernetes 클러스터 배포 테스트"
echo "ImageBuilder — 컨테이너 이미지 빌드"
echo "========================================"

# === 0. 클러스터 연결 확인 ===
echo ""
echo "4.0 Kubernetes 클러스터 연결 확인"
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${YELLOW}[SKIP]${NC} Kubernetes 클러스터에 연결되지 않음"
    echo "       minikube start 으로 클러스터를 시작하세요"
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
    echo "정리 완료"
}

# 스크립트 종료 시 정리
trap cleanup EXIT

# === 1. Registry Addon 확인 ===
echo ""
echo "4.1 minikube Registry Addon 확인"
if kubectl get svc registry -n kube-system &>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} Registry 서비스 동작 중"
    ((PASSED++))
else
    echo -e "${YELLOW}[INFO]${NC} Registry addon 미활성 — 활성화 시도 중..."
    if command -v minikube &>/dev/null; then
        minikube addons enable registry 2>/dev/null || true
        echo "    registry Pod 준비 대기 (최대 120초)..."
        if kubectl wait --for=condition=Ready pod -l actual-registry=true \
            -n kube-system --timeout=120s 2>/dev/null; then
            echo -e "${GREEN}[PASS]${NC} Registry addon 활성화 성공"
            ((PASSED++))
        else
            echo -e "${RED}[FAIL]${NC} Registry addon 활성화 실패"
            echo "       minikube addons enable registry 실행 후 재시도하세요"
            ((FAILED++))
            echo ""
            echo "========================================"
            echo "결과: ${PASSED} 통과, ${FAILED} 실패"
            echo "========================================"
            exit 1
        fi
    else
        echo -e "${RED}[FAIL]${NC} minikube 명령어를 찾을 수 없음"
        ((FAILED++))
        exit 1
    fi
fi

# === 2. 테스트 네임스페이스 생성 ===
echo ""
echo "4.2 테스트 네임스페이스 생성"
kubectl create namespace $NAMESPACE 2>/dev/null || true
if kubectl get namespace $NAMESPACE &>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} 네임스페이스 '$NAMESPACE' 생성됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 네임스페이스 생성 실패"
    ((FAILED++))
    exit 1
fi

# === 3. 빌드 컨텍스트 ConfigMap 적용 ===
echo ""
echo "4.3 빌드 컨텍스트 ConfigMap 적용"
if kubectl apply -n $NAMESPACE -f "$MANIFEST_DIR/build-context-configmap.yml"; then
    echo -e "${GREEN}[PASS]${NC} build-context ConfigMap 적용 성공"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} ConfigMap 적용 실패"
    ((FAILED++))
fi

# === 4. Kaniko 빌드 ===
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Kaniko 이미지 빌드${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "4.4 Kaniko 빌드 Job 실행"
if kubectl apply -n $NAMESPACE -f "$MANIFEST_DIR/kaniko-build-job.yml"; then
    echo -e "${GREEN}[PASS]${NC} Kaniko 빌드 Job 적용 성공"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Kaniko 빌드 Job 적용 실패"
    ((FAILED++))
fi

echo ""
echo "4.5 Kaniko 빌드 완료 대기 (최대 300초)"
echo "    첫 실행 시 이미지 pull에 시간이 걸릴 수 있습니다..."
if kubectl wait --for=condition=Complete job/kaniko-build -n $NAMESPACE --timeout=300s 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} Kaniko 빌드 완료"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Kaniko 빌드 실패 또는 타임아웃"
    echo "    Job 상태:"
    kubectl get jobs -n $NAMESPACE 2>/dev/null || true
    echo "    Pod 로그:"
    kubectl logs -n $NAMESPACE -l app=kaniko-build --tail=20 2>/dev/null || true
    ((FAILED++))
fi

echo ""
echo "4.6 Kaniko 빌드 로그 확인"
echo "---"
kubectl logs -n $NAMESPACE -l app=kaniko-build -c kaniko --tail=10 2>/dev/null || echo "    (로그 없음)"
echo "---"

# === 5. 빌드 이미지 검증 ===
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  빌드 이미지 검증${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "4.7 레지스트리에 이미지 push 확인"
# DNS 이름 대신 ClusterIP 사용 (insecure-registry가 IP 범위에만 적용)
REGISTRY_IP=$(kubectl get svc registry -n kube-system -o jsonpath='{.spec.clusterIP}')
CATALOG=$(kubectl run curl-check -n $NAMESPACE --image=busybox:1.36 --restart=Never \
    --rm -i --quiet -- wget -q -O- "http://${REGISTRY_IP}/v2/_catalog" 2>/dev/null || echo "")
if echo "$CATALOG" | grep -q "imagebuilder-test"; then
    echo -e "${GREEN}[PASS]${NC} 레지스트리에 imagebuilder-test 이미지 존재"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 레지스트리에 이미지 미확인"
    echo "    카탈로그: $CATALOG"
    ((FAILED++))
fi

echo ""
echo "4.8 빌드된 이미지로 Pod 실행 (ClusterIP로 pull)"
# minikube insecure-registry는 IP 범위에만 적용되므로 ClusterIP 사용
kubectl run verify-pod -n $NAMESPACE \
    --image="${REGISTRY_IP}/imagebuilder-test:kaniko" \
    --port=80 --restart=Never 2>/dev/null || true
if kubectl wait --for=condition=Ready pod/verify-pod -n $NAMESPACE --timeout=180s 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} 빌드된 이미지 Pod 실행 중"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 빌드된 이미지 Pod 시작 실패"
    kubectl get pod verify-pod -n $NAMESPACE 2>/dev/null || true
    ((FAILED++))
fi

echo ""
echo "4.9 HTTP 응답 검증"
POD_PHASE=$(kubectl get pod verify-pod -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$POD_PHASE" = "Running" ]; then
    RESPONSE=$(kubectl exec -n $NAMESPACE verify-pod -- wget -q -O- http://localhost 2>/dev/null || echo "")
    if echo "$RESPONSE" | grep -q "Built inside Kubernetes"; then
        echo -e "${GREEN}[PASS]${NC} HTTP 응답에 'Built inside Kubernetes' 확인"
        ((PASSED++))
    else
        echo -e "${RED}[FAIL]${NC} 예상 응답 미확인"
        echo "    실제 응답: $RESPONSE"
        ((FAILED++))
    fi
else
    echo -e "${RED}[FAIL]${NC} verify Pod가 Running 상태가 아님 (현재: $POD_PHASE)"
    ((FAILED++))
fi

# === 6. BuildKit 단발성 빌드 ===
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  BuildKit 단발성 빌드 (daemonless)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "4.10 BuildKit daemonless 빌드 Job 실행"
if kubectl apply -n $NAMESPACE -f "$MANIFEST_DIR/buildkit-daemonless-job.yml"; then
    echo -e "${GREEN}[PASS]${NC} BuildKit daemonless 빌드 Job 적용 성공"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} BuildKit daemonless 빌드 Job 적용 실패"
    ((FAILED++))
fi

echo ""
echo "4.11 BuildKit daemonless 빌드 완료 대기 (최대 300초)"
if kubectl wait --for=condition=Complete job/buildkit-daemonless-build -n $NAMESPACE --timeout=300s 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} BuildKit daemonless 빌드 완료"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} BuildKit daemonless 빌드 실패 또는 타임아웃"
    echo "    Job 상태:"
    kubectl get jobs -n $NAMESPACE 2>/dev/null || true
    echo "    Pod 로그:"
    kubectl logs -n $NAMESPACE -l app=buildkit-daemonless-build --tail=20 2>/dev/null || true
    ((FAILED++))
fi

# === 7. BuildKit Daemon + Client 빌드 ===
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  BuildKit Daemon + Client 빌드${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "4.12 BuildKit Daemon 배포"
if kubectl apply -n $NAMESPACE -f "$MANIFEST_DIR/buildkit-daemon-deployment.yml"; then
    echo -e "${GREEN}[PASS]${NC} BuildKit Daemon 배포 성공"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} BuildKit Daemon 배포 실패"
    ((FAILED++))
fi

echo ""
echo "4.13 BuildKit Daemon Pod 준비 대기 (최대 180초)"
if kubectl wait --for=condition=Ready pod -l app=buildkitd -n $NAMESPACE --timeout=180s 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} BuildKit Daemon 실행 중"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} BuildKit Daemon 시작 실패"
    echo "    Pod 상태:"
    kubectl get pods -n $NAMESPACE -l app=buildkitd 2>/dev/null || true
    ((FAILED++))
fi

echo ""
echo "4.14 BuildKit Client 빌드 Job 실행"
if kubectl apply -n $NAMESPACE -f "$MANIFEST_DIR/buildkit-build-job.yml"; then
    echo -e "${GREEN}[PASS]${NC} BuildKit Client 빌드 Job 적용 성공"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} BuildKit Client 빌드 Job 적용 실패"
    ((FAILED++))
fi

echo ""
echo "4.15 BuildKit Client 빌드 완료 대기 (최대 300초)"
if kubectl wait --for=condition=Complete job/buildkit-client-build -n $NAMESPACE --timeout=300s 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} BuildKit Client 빌드 완료"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} BuildKit Client 빌드 실패 또는 타임아웃"
    echo "    Job 상태:"
    kubectl get jobs -n $NAMESPACE 2>/dev/null || true
    echo "    Pod 로그:"
    kubectl logs -n $NAMESPACE -l app=buildkit-client-build --tail=20 2>/dev/null || true
    ((FAILED++))
fi

# === 8. 최종 상태 요약 ===
echo ""
echo "========================================"
echo "리소스 상태 요약:"
echo "========================================"
kubectl get all -n $NAMESPACE 2>/dev/null
echo ""
echo "Job 상태:"
kubectl get jobs -n $NAMESPACE 2>/dev/null
echo ""

echo "========================================"
echo "결과: ${PASSED} 통과, ${FAILED} 실패"
echo "========================================"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
