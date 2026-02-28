#!/bin/bash
# HashiCorp Vault 설치 스크립트 (CSI Driver 및 Sidecar Injector용)

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_step() { echo -e "${YELLOW}[STEP]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=========================================="
echo "HashiCorp Vault 설치 (Dev Mode)"
echo "=========================================="
echo ""

# Helm repo 추가
print_step "HashiCorp Helm 저장소 추가"
helm repo add hashicorp https://helm.releases.hashicorp.com 2>/dev/null || true
helm repo update

# 네임스페이스 생성
print_step "vault 네임스페이스 생성"
kubectl create namespace vault --dry-run=client -o yaml | kubectl apply -f -

# 기존 설치 확인
if helm status vault -n vault &>/dev/null; then
    echo "  Vault가 이미 설치되어 있습니다."
    kubectl get pods -n vault
else
    print_step "Vault 설치 (dev mode, injector, csi 활성화)"
    helm install vault hashicorp/vault \
        --namespace vault \
        --set "server.dev.enabled=true" \
        --set "server.dev.devRootToken=root" \
        --set "injector.enabled=true" \
        --set "csi.enabled=true"
fi

# Vault 준비 대기
print_step "Vault Pod 준비 대기"
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=vault -n vault --timeout=300s

# Vault 상태 확인
print_step "Vault 상태 확인"
kubectl get pods -n vault

# Vault 시크릿 및 인증 설정
print_step "Vault 초기 설정"
kubectl exec -n vault vault-0 -- vault secrets enable -path=secret kv-v2 2>/dev/null || echo "  secret engine already enabled"

# 테스트 시크릿 생성
kubectl exec -n vault vault-0 -- vault kv put secret/database \
    username="db-admin" \
    password="supersecret123" \
    connection_string="postgres://localhost:5432/mydb"

kubectl exec -n vault vault-0 -- vault kv put secret/myapp \
    api_key="vault-managed-api-key-xyz789" \
    username="app-user" \
    password="app-secret-password"

# Kubernetes 인증 설정
print_step "Kubernetes 인증 설정"
kubectl exec -n vault vault-0 -- vault auth enable kubernetes 2>/dev/null || echo "  kubernetes auth already enabled"

kubectl exec -n vault vault-0 -- sh -c '
vault write auth/kubernetes/config \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"
'

# 정책 생성
kubectl exec -n vault vault-0 -- vault policy write myapp - <<EOF
path "secret/data/myapp" {
  capabilities = ["read"]
}
path "secret/data/database" {
  capabilities = ["read"]
}
EOF

kubectl exec -n vault vault-0 -- vault policy write csi-test - <<EOF
path "secret/data/database" {
  capabilities = ["read"]
}
EOF

# 역할 생성 (Sidecar Injector용)
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/myapp \
    bound_service_account_names=myapp-sa \
    bound_service_account_namespaces=vault-sidecar-test \
    policies=myapp \
    ttl=24h

# 역할 생성 (CSI Driver용)
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/csi-test \
    bound_service_account_names=csi-test-sa \
    bound_service_account_namespaces=csi-test \
    policies=csi-test \
    ttl=24h

echo ""
print_success "Vault 설치 및 설정 완료!"
echo ""
echo "Vault UI 접속: kubectl port-forward -n vault svc/vault 8200:8200"
echo "Root Token: root"
