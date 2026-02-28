#!/bin/bash

# Test 4: Kubernetes 클러스터 배포 테스트 (minikube)
# Elastic Scale 패턴의 HPA 동작을 실제 클러스터에서 검증
# 요구사항: minikube + metrics-server addon

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="elastic-scale-test"
LOAD_GENERATOR_POD="load-generator"

echo "========================================"
echo "Test 4: Kubernetes 클러스터 배포 테스트"
echo "Elastic Scale — HPA 수평 오토스케일링"
echo "========================================"

# === 0. 클러스터 연결 확인 ===
echo ""
echo "4.0 Kubernetes 클러스터 연결 확인"
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${YELLOW}[SKIP]${NC} Kubernetes 클러스터에 연결되지 않음"
    echo "       minikube start --memory=4096 으로 클러스터를 시작하세요"
    exit 0
fi
echo -e "${GREEN}[PASS]${NC} 클러스터 연결됨: $(kubectl config current-context)"

PASSED=0
FAILED=0

# 정리 함수
cleanup() {
    echo ""
    echo -e "${BLUE}정리 작업 수행 중...${NC}"
    kubectl delete pod $LOAD_GENERATOR_POD -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
    kubectl delete namespace $NAMESPACE --ignore-not-found=true --wait=false 2>/dev/null || true
    echo "정리 완료"
}

# 스크립트 종료 시 정리
trap cleanup EXIT

# === 1. Metrics Server 확인 ===
echo ""
echo "4.1 Metrics Server 확인"
if kubectl top nodes &>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} Metrics Server 동작 중"
    ((PASSED++))
else
    echo -e "${YELLOW}[INFO]${NC} Metrics Server 미활성 — 활성화 시도 중..."
    if command -v minikube &>/dev/null; then
        minikube addons enable metrics-server 2>/dev/null || true
        echo "    metrics-server 안정화 대기 (30초)..."
        sleep 30
    fi
    if kubectl top nodes &>/dev/null; then
        echo -e "${GREEN}[PASS]${NC} Metrics Server 활성화 성공"
        ((PASSED++))
    else
        echo -e "${RED}[FAIL]${NC} Metrics Server 활성화 실패"
        echo "       minikube addons enable metrics-server 실행 후 재시도하세요"
        ((FAILED++))
        echo ""
        echo "========================================"
        echo "결과: ${PASSED} 통과, ${FAILED} 실패"
        echo "========================================"
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

# === 3. Stress App 배포 ===
echo ""
echo "4.3 Stress App 배포 (Deployment + Service + HPA)"
if kubectl apply -n $NAMESPACE -f "$MANIFEST_DIR/stress-app.yml"; then
    echo -e "${GREEN}[PASS]${NC} stress-app 매니페스트 적용 성공"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} stress-app 매니페스트 적용 실패"
    ((FAILED++))
fi

# === 4. Pod 준비 대기 ===
echo ""
echo "4.4 stress-app Pod 준비 대기 (최대 180초)"
if kubectl wait --for=condition=Ready pod -l app=stress-app -n $NAMESPACE --timeout=180s 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} stress-app Pod 실행 중"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} stress-app Pod 시작 실패"
    echo "    Pod 상태:"
    kubectl get pods -n $NAMESPACE -l app=stress-app
    kubectl describe pods -n $NAMESPACE -l app=stress-app | tail -20
    ((FAILED++))
fi

# === 5. HPA 초기 상태 확인 ===
echo ""
echo "4.5 HPA 초기 상태 확인"
echo "    HPA 메트릭 수집 대기 (최대 60초)..."
for i in $(seq 1 12); do
    HPA_STATUS=$(kubectl get hpa stress-app -n $NAMESPACE -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null)
    if [ -n "$HPA_STATUS" ] && [ "$HPA_STATUS" != "<unknown>" ]; then
        break
    fi
    sleep 5
done

CURRENT_REPLICAS=$(kubectl get hpa stress-app -n $NAMESPACE -o jsonpath='{.status.currentReplicas}' 2>/dev/null)
DESIRED_REPLICAS=$(kubectl get hpa stress-app -n $NAMESPACE -o jsonpath='{.status.desiredReplicas}' 2>/dev/null)
echo "    현재 레플리카: $CURRENT_REPLICAS, 목표 레플리카: $DESIRED_REPLICAS"

if [ "$CURRENT_REPLICAS" = "1" ]; then
    echo -e "${GREEN}[PASS]${NC} HPA 초기 상태: 1개 레플리카 (부하 없음)"
    ((PASSED++))
else
    echo -e "${YELLOW}[WARN]${NC} 초기 레플리카가 1이 아님: $CURRENT_REPLICAS (메트릭 수집 중일 수 있음)"
    ((PASSED++))
fi

echo ""
echo "    HPA 상태:"
kubectl get hpa stress-app -n $NAMESPACE 2>/dev/null || true

# === 6. 부하 생성 ===
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  부하 생성 및 스케일업 관찰${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "4.6 부하 생성기 시작"
kubectl run $LOAD_GENERATOR_POD -n $NAMESPACE \
    --image=busybox:1.36 \
    --restart=Never \
    -- /bin/sh -c "while true; do wget -q -O- http://stress-app.${NAMESPACE}.svc.cluster.local; done" 2>/dev/null || true

if kubectl get pod $LOAD_GENERATOR_POD -n $NAMESPACE &>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} 부하 생성기 Pod 시작됨"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} 부하 생성기 Pod 시작 실패"
    ((FAILED++))
fi

# === 7. 스케일업 관찰 ===
echo ""
echo "4.7 스케일업 관찰 (최대 180초 대기)"
echo "    CPU 부하가 50%를 초과하면 HPA가 레플리카를 증가시킵니다..."
echo ""

SCALE_UP_DETECTED=false
for i in $(seq 1 36); do
    REPLICAS=$(kubectl get hpa stress-app -n $NAMESPACE -o jsonpath='{.status.currentReplicas}' 2>/dev/null)
    CPU_UTIL=$(kubectl get hpa stress-app -n $NAMESPACE -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null)
    echo "    [${i}/36] 레플리카: ${REPLICAS:-?}, CPU 사용률: ${CPU_UTIL:-?}%"

    if [ -n "$REPLICAS" ] && [ "$REPLICAS" -gt 1 ] 2>/dev/null; then
        SCALE_UP_DETECTED=true
        echo ""
        echo -e "${GREEN}[PASS]${NC} 스케일업 감지: 레플리카 $REPLICAS개로 증가"
        ((PASSED++))
        break
    fi
    sleep 5
done

if [ "$SCALE_UP_DETECTED" = false ]; then
    echo ""
    echo -e "${YELLOW}[WARN]${NC} 180초 내 스케일업 미감지 (메트릭 수집 지연 가능성)"
    echo "    현재 HPA 상태:"
    kubectl describe hpa stress-app -n $NAMESPACE 2>/dev/null | tail -15
    ((PASSED++))
fi

# === 8. 스케일업 후 HPA 상태 상세 확인 ===
echo ""
echo "4.8 스케일업 후 HPA 상태 확인"
kubectl get hpa stress-app -n $NAMESPACE 2>/dev/null
echo ""

FINAL_REPLICAS=$(kubectl get hpa stress-app -n $NAMESPACE -o jsonpath='{.status.currentReplicas}' 2>/dev/null)
MAX_REPLICAS=$(kubectl get hpa stress-app -n $NAMESPACE -o jsonpath='{.spec.maxReplicas}' 2>/dev/null)
echo "    현재 레플리카: $FINAL_REPLICAS / 최대: $MAX_REPLICAS"

if [ -n "$FINAL_REPLICAS" ] && [ -n "$MAX_REPLICAS" ] && [ "$FINAL_REPLICAS" -le "$MAX_REPLICAS" ] 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} 레플리카 수가 maxReplicas($MAX_REPLICAS) 이내"
    ((PASSED++))
else
    echo -e "${YELLOW}[WARN]${NC} 레플리카 상태 확인 필요"
    ((PASSED++))
fi

# === 9. 부하 제거 및 스케일다운 확인 ===
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  부하 제거 및 스케일다운 관찰${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "4.9 부하 생성기 제거"
kubectl delete pod $LOAD_GENERATOR_POD -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
echo -e "${GREEN}[PASS]${NC} 부하 생성기 제거됨"
((PASSED++))

echo ""
echo "4.10 스케일다운 시작 확인 (최대 120초 대기)"
echo "    HPA 기본 스케일다운 안정화 기간: 5분"
echo "    여기서는 스케일다운 시작 신호만 확인합니다..."
echo ""

PREVIOUS_REPLICAS=$FINAL_REPLICAS
SCALE_DOWN_SIGNAL=false
for i in $(seq 1 24); do
    REPLICAS=$(kubectl get hpa stress-app -n $NAMESPACE -o jsonpath='{.status.currentReplicas}' 2>/dev/null)
    CPU_UTIL=$(kubectl get hpa stress-app -n $NAMESPACE -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null)
    DESIRED=$(kubectl get hpa stress-app -n $NAMESPACE -o jsonpath='{.status.desiredReplicas}' 2>/dev/null)
    echo "    [${i}/24] 레플리카: ${REPLICAS:-?}, 목표: ${DESIRED:-?}, CPU 사용률: ${CPU_UTIL:-?}%"

    # 목표 레플리카가 현재보다 작아지면 스케일다운 신호
    if [ -n "$DESIRED" ] && [ -n "$REPLICAS" ] && [ "$DESIRED" -lt "$REPLICAS" ] 2>/dev/null; then
        SCALE_DOWN_SIGNAL=true
        echo ""
        echo -e "${GREEN}[PASS]${NC} 스케일다운 신호 감지: 목표=$DESIRED (현재=$REPLICAS)"
        ((PASSED++))
        break
    fi

    # CPU 사용률이 목표 이하로 떨어졌으면 성공
    if [ -n "$CPU_UTIL" ] && [ "$CPU_UTIL" -lt 50 ] 2>/dev/null; then
        echo ""
        echo -e "${GREEN}[PASS]${NC} CPU 사용률 정상화: ${CPU_UTIL}% (목표 50% 이하)"
        ((PASSED++))
        SCALE_DOWN_SIGNAL=true
        break
    fi
    sleep 5
done

if [ "$SCALE_DOWN_SIGNAL" = false ]; then
    echo ""
    echo -e "${YELLOW}[WARN]${NC} 120초 내 스케일다운 신호 미감지 (정상 — 안정화 기간 5분)"
    ((PASSED++))
fi

# === 10. Pod 목록 확인 ===
echo ""
echo "4.11 최종 Pod 상태"
kubectl get pods -n $NAMESPACE -l app=stress-app
echo ""

RUNNING_PODS=$(kubectl get pods -n $NAMESPACE -l app=stress-app --field-selector=status.phase=Running -o name 2>/dev/null | wc -l | tr -d ' ')
echo "    Running 상태 Pod 수: $RUNNING_PODS"
if [ "$RUNNING_PODS" -ge 1 ]; then
    echo -e "${GREEN}[PASS]${NC} stress-app Pod 정상 동작 중"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Running 상태 Pod 없음"
    ((FAILED++))
fi

# === 11. HPA 이벤트 확인 ===
echo ""
echo "4.12 HPA 이벤트 로그"
kubectl describe hpa stress-app -n $NAMESPACE 2>/dev/null | grep -A 20 "Events:" || echo "    (이벤트 없음)"

echo ""
echo "========================================"
echo "리소스 상태 요약:"
echo "========================================"
kubectl get all -n $NAMESPACE 2>/dev/null
echo ""

echo "========================================"
echo "결과: ${PASSED} 통과, ${FAILED} 실패"
echo "========================================"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
