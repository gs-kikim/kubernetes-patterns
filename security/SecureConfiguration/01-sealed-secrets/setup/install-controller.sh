#!/bin/bash
# Sealed Secrets Controller 설치 스크립트

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "${YELLOW}[STEP]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

echo "=========================================="
echo "Sealed Secrets Controller 설치"
echo "=========================================="
echo ""

# Helm repo 추가
print_step "Sealed Secrets Helm 저장소 추가"
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets 2>/dev/null || true
helm repo update

# 네임스페이스 생성
print_step "sealed-secrets 네임스페이스 생성"
kubectl create namespace sealed-secrets --dry-run=client -o yaml | kubectl apply -f -

# 기존 설치 확인
if helm status sealed-secrets -n sealed-secrets &>/dev/null; then
    echo "  Sealed Secrets가 이미 설치되어 있습니다."
else
    print_step "Sealed Secrets Controller 설치"
    helm install sealed-secrets sealed-secrets/sealed-secrets \
        --namespace sealed-secrets \
        --set-string fullnameOverride=sealed-secrets-controller
fi

# 준비 대기
print_step "Controller Pod 준비 대기"
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=sealed-secrets \
    -n sealed-secrets --timeout=120s

# 공개키 가져오기
print_step "공개키 가져오기"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubeseal --fetch-cert \
    --controller-name=sealed-secrets-controller \
    --controller-namespace=sealed-secrets > "$SCRIPT_DIR/../pub-sealed-secrets.pem"

echo ""
print_success "Sealed Secrets Controller 설치 완료!"
echo "공개키 저장 위치: $SCRIPT_DIR/../pub-sealed-secrets.pem"
