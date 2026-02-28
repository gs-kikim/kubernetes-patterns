#!/bin/bash
# Vault Sidecar Injector용 Kubernetes 인증 설정

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "${YELLOW}[STEP]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

NAMESPACE="vault-sidecar-test"

echo "=========================================="
echo "Vault Sidecar Injector 설정"
echo "=========================================="
echo ""

# Vault 상태 확인
print_step "Vault 상태 확인"
if ! kubectl get pod vault-0 -n vault &>/dev/null; then
    echo "Vault가 설치되어 있지 않습니다."
    echo "먼저 00-setup/02-install-vault.sh를 실행하세요."
    exit 1
fi

# Vault Injector 확인
print_step "Vault Agent Injector 확인"
kubectl get pods -n vault -l app.kubernetes.io/name=vault-agent-injector

# 테스트 네임스페이스 및 ServiceAccount 생성
print_step "테스트 환경 생성"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
kubectl create serviceaccount myapp-sa -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Vault 역할 확인/생성
print_step "Vault 역할 확인/생성"
kubectl exec -n vault vault-0 -- vault read auth/kubernetes/role/myapp 2>/dev/null || \
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/myapp \
    bound_service_account_names=myapp-sa \
    bound_service_account_namespaces=$NAMESPACE \
    policies=myapp \
    ttl=24h

print_success "Vault Sidecar Injector 설정 완료!"
