#!/bin/bash
# Sealed Secrets 테스트 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/.."
NAMESPACE="sealed-secrets-test"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "${YELLOW}[STEP]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=========================================="
echo "Sealed Secrets 테스트"
echo "=========================================="
echo ""

# Controller 설치 확인
print_step "1. Sealed Secrets Controller 확인"
if ! kubectl get deployment sealed-secrets-controller -n sealed-secrets &>/dev/null; then
    echo "  Controller가 설치되어 있지 않습니다. 설치를 시작합니다..."
    bash "$BASE_DIR/setup/install-controller.sh"
fi
kubectl get pods -n sealed-secrets -l app.kubernetes.io/name=sealed-secrets

# 테스트 네임스페이스 생성
print_step "2. 테스트 네임스페이스 생성"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# 원본 Secret을 SealedSecret으로 암호화
print_step "3. Secret을 SealedSecret으로 암호화"
kubeseal --format=yaml \
    --controller-name=sealed-secrets-controller \
    --controller-namespace=sealed-secrets \
    < "$BASE_DIR/manifests/01-original-secret.yaml" > /tmp/sealed-secret.yaml

echo "  SealedSecret 생성됨:"
cat /tmp/sealed-secret.yaml | head -20
echo "  ..."

# 암호화된 데이터 확인
print_step "4. 암호화된 데이터 확인"
ENCRYPTED_DATA=$(grep "encryptedData:" -A 10 /tmp/sealed-secret.yaml || true)
if [[ -n "$ENCRYPTED_DATA" ]]; then
    print_success "encryptedData 필드 확인됨 (암호화 성공)"
else
    print_error "encryptedData 필드를 찾을 수 없습니다"
    exit 1
fi

# SealedSecret 적용
print_step "5. SealedSecret을 클러스터에 적용"
kubectl apply -f /tmp/sealed-secret.yaml

# Secret 생성 대기
print_step "6. Secret 자동 생성 대기"
sleep 5

# Secret 확인
print_step "7. 생성된 Secret 확인"
if kubectl get secret db-credentials -n $NAMESPACE &>/dev/null; then
    print_success "Secret이 자동으로 생성됨!"
    kubectl get secret db-credentials -n $NAMESPACE
else
    print_error "Secret이 생성되지 않았습니다"
    kubectl get sealedsecrets -n $NAMESPACE
    kubectl describe sealedsecret db-credentials -n $NAMESPACE
    exit 1
fi

# Secret 값 검증
print_step "8. Secret 값 검증"
DECODED_USERNAME=$(kubectl get secret db-credentials -n $NAMESPACE -o jsonpath='{.data.username}' | base64 -d)
DECODED_PASSWORD=$(kubectl get secret db-credentials -n $NAMESPACE -o jsonpath='{.data.password}' | base64 -d)

if [[ "$DECODED_USERNAME" == "admin" ]] && [[ "$DECODED_PASSWORD" == "supersecretpassword123" ]]; then
    print_success "Secret 값이 원본과 일치합니다!"
    echo "  Username: $DECODED_USERNAME"
    echo "  Password: [VERIFIED]"
else
    print_error "Secret 값이 일치하지 않습니다!"
    echo "  Expected Username: admin, Got: $DECODED_USERNAME"
    exit 1
fi

# Pod에서 Secret 사용 테스트
print_step "9. Pod에서 Secret 사용 테스트"
kubectl apply -f "$BASE_DIR/manifests/02-test-pod.yaml"
kubectl wait --for=condition=Ready pod/secret-test-pod -n $NAMESPACE --timeout=60s || true
sleep 3
echo "  Pod 로그:"
kubectl logs secret-test-pod -n $NAMESPACE || true

echo ""
echo "=========================================="
print_success "Sealed Secrets 테스트 완료!"
echo "=========================================="
echo ""
echo "요약:"
echo "  - SealedSecret으로 암호화된 데이터는 Git에 안전하게 저장 가능"
echo "  - Controller가 자동으로 복호화하여 Kubernetes Secret 생성"
echo "  - Pod에서 환경변수로 Secret 값 사용 가능"
