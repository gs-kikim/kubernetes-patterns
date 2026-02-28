#!/bin/bash
# Secrets Store CSI Driver 테스트 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ROOT_DIR="$BASE_DIR/.."
NAMESPACE="csi-test"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "${YELLOW}[STEP]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=========================================="
echo "Secrets Store CSI Driver 테스트"
echo "=========================================="
echo ""

# CSI Driver 설치 확인
print_step "1. Secrets Store CSI Driver 확인"
if ! kubectl get daemonset -n kube-system -l app=secrets-store-csi-driver &>/dev/null; then
    echo "  CSI Driver가 설치되어 있지 않습니다. 설치를 시작합니다..."
    bash "$BASE_DIR/setup/install-csi-driver.sh"
fi
kubectl get pods -n kube-system -l app=secrets-store-csi-driver

# Vault 설치 확인
print_step "2. Vault 설치 확인"
if ! kubectl get pod vault-0 -n vault &>/dev/null; then
    echo "  Vault가 설치되어 있지 않습니다. 설치를 시작합니다..."
    bash "$ROOT_DIR/00-setup/02-install-vault.sh"
fi

# Vault CSI Provider 확인
print_step "3. Vault CSI Provider 확인"
kubectl get pods -n vault -l app.kubernetes.io/name=vault-csi-provider || echo "  (Vault CSI Provider는 vault-agent가 대신 처리)"

# 테스트 환경 설정
print_step "4. 테스트 환경 설정"
bash "$BASE_DIR/setup/configure-vault.sh"

# SecretProviderClass 생성
print_step "5. SecretProviderClass 생성"
kubectl apply -f "$BASE_DIR/manifests/01-secret-provider-class.yaml"

# SecretProviderClass 확인
kubectl get secretproviderclass -n $NAMESPACE

# 테스트 Pod 생성
print_step "6. 테스트 Pod 생성"
kubectl delete pod csi-test-pod -n $NAMESPACE --ignore-not-found=true
kubectl apply -f "$BASE_DIR/manifests/02-test-pod.yaml"

# Pod 준비 대기
print_step "7. Pod 준비 대기"
echo "  Pod가 Running 상태가 될 때까지 대기합니다..."
kubectl wait --for=condition=Ready pod/csi-test-pod -n $NAMESPACE --timeout=120s || {
    print_error "Pod가 Ready 상태가 되지 않았습니다"
    echo "  Pod 상태:"
    kubectl get pod csi-test-pod -n $NAMESPACE
    echo "  Pod 이벤트:"
    kubectl describe pod csi-test-pod -n $NAMESPACE | tail -20
    exit 1
}

# 마운트된 Secret 확인
print_step "8. CSI 마운트된 Secret 파일 확인"
echo "  마운트된 파일 목록:"
kubectl exec csi-test-pod -n $NAMESPACE -- ls -la /mnt/secrets-store/

# Secret 값 검증
print_step "9. Secret 값 검증"
DB_USERNAME=$(kubectl exec csi-test-pod -n $NAMESPACE -- cat /mnt/secrets-store/db-username)
if [[ "$DB_USERNAME" == "db-admin" ]]; then
    print_success "CSI 마운트된 Secret 값 확인!"
    echo "  Username: $DB_USERNAME"
else
    print_error "Secret 값이 다릅니다: $DB_USERNAME"
    exit 1
fi

# syncSecret 확인 (K8s Secret으로 동기화)
print_step "10. syncSecret 확인 (K8s Secret 동기화)"
if kubectl get secret database-creds-synced -n $NAMESPACE &>/dev/null; then
    print_success "K8s Secret도 자동 생성됨!"
    kubectl get secret database-creds-synced -n $NAMESPACE
    SYNCED_USERNAME=$(kubectl get secret database-creds-synced -n $NAMESPACE -o jsonpath='{.data.username}' | base64 -d)
    echo "  동기화된 Username: $SYNCED_USERNAME"
else
    echo "  (syncSecret은 Pod가 마운트한 후에 생성됩니다)"
fi

# Pod 로그 확인
print_step "11. Pod 로그 확인"
kubectl logs csi-test-pod -n $NAMESPACE || true

echo ""
echo "=========================================="
print_success "Secrets Store CSI Driver 테스트 완료!"
echo "=========================================="
echo ""
echo "요약:"
echo "  - Secret이 CSI 볼륨으로 마운트됨 (/mnt/secrets-store/)"
echo "  - etcd에 Secret이 저장되지 않음 (Vault에서 직접 가져옴)"
echo "  - syncSecret으로 K8s Secret도 생성 가능"
echo ""
echo "핵심 장점:"
echo "  - 클러스터에 Secret이 저장되지 않아 더 안전"
echo "  - Vault의 동적 Secret, 자동 로테이션 기능 활용 가능"
