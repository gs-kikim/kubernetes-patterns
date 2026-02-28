#!/bin/bash
# External Secrets Operator (Fake Provider) 테스트 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/.."
NAMESPACE="eso-test"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "${YELLOW}[STEP]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=========================================="
echo "External Secrets Operator 테스트 (Fake Provider)"
echo "=========================================="
echo ""

# ESO 설치 확인
print_step "1. External Secrets Operator 확인"
if ! kubectl get deployment external-secrets -n external-secrets &>/dev/null; then
    echo "  ESO가 설치되어 있지 않습니다. 설치를 시작합니다..."
    bash "$BASE_DIR/setup/install-eso.sh"
fi
kubectl get pods -n external-secrets -l app.kubernetes.io/name=external-secrets

# 테스트 네임스페이스 생성
print_step "2. 테스트 네임스페이스 생성"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# SecretStore 생성
print_step "3. Fake SecretStore 생성"
kubectl apply -f "$BASE_DIR/manifests/01-fake-secret-store.yaml"

# SecretStore 상태 확인
print_step "4. SecretStore 상태 확인"
sleep 3
kubectl get secretstore fake-store -n $NAMESPACE
STATUS=$(kubectl get secretstore fake-store -n $NAMESPACE -o jsonpath='{.status.conditions[0].status}')
if [[ "$STATUS" == "True" ]]; then
    print_success "SecretStore가 Ready 상태입니다!"
else
    print_error "SecretStore가 Ready 상태가 아닙니다"
    kubectl describe secretstore fake-store -n $NAMESPACE
    exit 1
fi

# ExternalSecret 생성
print_step "5. ExternalSecret 생성"
kubectl apply -f "$BASE_DIR/manifests/02-external-secret.yaml"

# Secret 동기화 대기
print_step "6. Secret 동기화 대기"
sleep 5

# ExternalSecret 상태 확인
print_step "7. ExternalSecret 상태 확인"
kubectl get externalsecret -n $NAMESPACE
DB_SYNC_STATUS=$(kubectl get externalsecret db-credentials -n $NAMESPACE -o jsonpath='{.status.conditions[0].status}')
API_SYNC_STATUS=$(kubectl get externalsecret api-credentials -n $NAMESPACE -o jsonpath='{.status.conditions[0].status}')

if [[ "$DB_SYNC_STATUS" == "True" ]] && [[ "$API_SYNC_STATUS" == "True" ]]; then
    print_success "모든 ExternalSecret이 동기화됨!"
else
    print_error "동기화 실패"
    kubectl describe externalsecret -n $NAMESPACE
    exit 1
fi

# 생성된 Secret 확인
print_step "8. 생성된 Kubernetes Secret 확인"
kubectl get secrets -n $NAMESPACE

# Secret 값 검증
print_step "9. Secret 값 검증"
DB_USERNAME=$(kubectl get secret db-credentials-secret -n $NAMESPACE -o jsonpath='{.data.username}' | base64 -d)
API_KEY=$(kubectl get secret api-credentials-secret -n $NAMESPACE -o jsonpath='{.data.api-key}' | base64 -d)

if [[ "$DB_USERNAME" == "fake-db-user" ]]; then
    print_success "DB credentials Secret 값 일치!"
    echo "  Username: $DB_USERNAME"
else
    print_error "DB credentials 값이 다릅니다: $DB_USERNAME"
    exit 1
fi

if [[ "$API_KEY" == "fake-api-key-xyz789" ]]; then
    print_success "API key Secret 값 일치!"
    echo "  API Key: $API_KEY"
else
    print_error "API key 값이 다릅니다: $API_KEY"
    exit 1
fi

# Pod에서 테스트
print_step "10. Pod에서 Secret 사용 테스트"
kubectl apply -f "$BASE_DIR/manifests/03-test-pod.yaml"
kubectl wait --for=condition=Ready pod/eso-test-pod -n $NAMESPACE --timeout=60s || true
sleep 3
echo "  Pod 로그:"
kubectl logs eso-test-pod -n $NAMESPACE || true

echo ""
echo "=========================================="
print_success "External Secrets Operator 테스트 완료!"
echo "=========================================="
echo ""
echo "요약:"
echo "  - Fake Provider로 외부 SMS 없이 ESO 테스트 가능"
echo "  - SecretStore: 외부 SMS 연결 설정"
echo "  - ExternalSecret: Secret 동기화 정의"
echo "  - refreshInterval: 자동 갱신 주기 설정 가능"
echo ""
echo "실제 환경에서는 AWS Secrets Manager, Azure Key Vault,"
echo "GCP Secret Manager, HashiCorp Vault 등과 연동합니다."
