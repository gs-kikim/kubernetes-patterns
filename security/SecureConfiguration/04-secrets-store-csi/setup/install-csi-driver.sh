#!/bin/bash
# Secrets Store CSI Driver 설치 스크립트

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "${YELLOW}[STEP]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

echo "=========================================="
echo "Secrets Store CSI Driver 설치"
echo "=========================================="
echo ""

# Helm repo 추가
print_step "Secrets Store CSI Driver Helm 저장소 추가"
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts 2>/dev/null || true
helm repo update

# 기존 설치 확인
if helm status csi-secrets-store -n kube-system &>/dev/null; then
    echo "  Secrets Store CSI Driver가 이미 설치되어 있습니다."
else
    print_step "Secrets Store CSI Driver 설치"
    helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
        --namespace kube-system \
        --set syncSecret.enabled=true \
        --set enableSecretRotation=true
fi

# 준비 대기
print_step "CSI Driver DaemonSet 준비 대기"
kubectl wait --for=condition=Ready pod -l app=secrets-store-csi-driver \
    -n kube-system --timeout=120s

# 상태 확인
print_step "설치 상태 확인"
kubectl get pods -n kube-system -l app=secrets-store-csi-driver
kubectl get daemonset -n kube-system -l app=secrets-store-csi-driver

echo ""
print_success "Secrets Store CSI Driver 설치 완료!"
echo ""
echo "다음으로 Vault Provider를 설치하려면:"
echo "  - Vault helm chart에서 csi.enabled=true 설정"
echo "  - 또는 02-install-vault.sh 스크립트 실행"
