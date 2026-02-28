#!/bin/bash
# External Secrets Operator 설치 스크립트

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "${YELLOW}[STEP]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

echo "=========================================="
echo "External Secrets Operator 설치"
echo "=========================================="
echo ""

# Helm repo 추가
print_step "External Secrets Helm 저장소 추가"
helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
helm repo update

# 네임스페이스 생성
print_step "external-secrets 네임스페이스 생성"
kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -

# 기존 설치 확인
if helm status external-secrets -n external-secrets &>/dev/null; then
    echo "  External Secrets Operator가 이미 설치되어 있습니다."
else
    print_step "External Secrets Operator 설치"
    helm install external-secrets external-secrets/external-secrets \
        --namespace external-secrets \
        --set installCRDs=true
fi

# 준비 대기
print_step "Operator Pod 준비 대기"
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=external-secrets \
    -n external-secrets --timeout=120s

# 상태 확인
print_step "설치 상태 확인"
kubectl get pods -n external-secrets

echo ""
print_success "External Secrets Operator 설치 완료!"
