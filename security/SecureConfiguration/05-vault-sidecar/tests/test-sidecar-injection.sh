#!/bin/bash
# Vault Sidecar Agent Injector 테스트 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ROOT_DIR="$BASE_DIR/.."
NAMESPACE="vault-sidecar-test"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "${YELLOW}[STEP]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=========================================="
echo "Vault Sidecar Agent Injector 테스트"
echo "=========================================="
echo ""

# Vault 설치 확인
print_step "1. Vault 및 Injector 확인"
if ! kubectl get pod vault-0 -n vault &>/dev/null; then
    echo "  Vault가 설치되어 있지 않습니다. 설치를 시작합니다..."
    bash "$ROOT_DIR/00-setup/02-install-vault.sh"
fi

# Vault Agent Injector 확인
echo "  Vault Agent Injector 상태:"
kubectl get pods -n vault -l app.kubernetes.io/name=vault-agent-injector

# 테스트 환경 설정
print_step "2. 테스트 환경 설정"
bash "$BASE_DIR/setup/configure-k8s-auth.sh"

# 기존 Deployment 삭제
print_step "3. 기존 테스트 리소스 정리"
kubectl delete deployment vault-sidecar-test -n $NAMESPACE --ignore-not-found=true
sleep 2

# Deployment 생성
print_step "4. Vault Sidecar Injection Deployment 생성"
kubectl apply -f "$BASE_DIR/manifests/01-test-deployment.yaml"

# Pod 준비 대기
print_step "5. Pod 준비 대기"
echo "  Pod가 Running 상태가 될 때까지 대기합니다..."
kubectl wait --for=condition=Ready pod -l app=vault-test -n $NAMESPACE --timeout=120s || {
    print_error "Pod가 Ready 상태가 되지 않았습니다"
    echo "  Pod 상태:"
    kubectl get pods -l app=vault-test -n $NAMESPACE
    echo "  Pod 이벤트:"
    kubectl describe pod -l app=vault-test -n $NAMESPACE | tail -30
    exit 1
}

# Sidecar 주입 확인
print_step "6. Sidecar 컨테이너 주입 확인"
POD_NAME=$(kubectl get pod -l app=vault-test -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
CONTAINERS=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.containers[*].name}')
echo "  Pod: $POD_NAME"
echo "  컨테이너 목록: $CONTAINERS"

if echo "$CONTAINERS" | grep -q "vault-agent"; then
    print_success "vault-agent sidecar가 주입됨!"
else
    print_error "vault-agent sidecar가 없습니다"
    exit 1
fi

# Init Container 확인
INIT_CONTAINERS=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.initContainers[*].name}')
echo "  Init 컨테이너: $INIT_CONTAINERS"

if echo "$INIT_CONTAINERS" | grep -q "vault-agent-init"; then
    print_success "vault-agent-init이 주입됨!"
fi

# Secret 파일 확인
print_step "7. 마운트된 Secret 파일 확인"
echo "  /vault/secrets/ 디렉토리:"
kubectl exec $POD_NAME -n $NAMESPACE -c app -- ls -la /vault/secrets/

# Secret 내용 확인
print_step "8. Secret 내용 확인"
echo "  === database.txt ==="
kubectl exec $POD_NAME -n $NAMESPACE -c app -- cat /vault/secrets/database.txt
echo ""
echo "  === api.txt ==="
kubectl exec $POD_NAME -n $NAMESPACE -c app -- cat /vault/secrets/api.txt

# 값 검증
print_step "9. Secret 값 검증"
DB_USERNAME=$(kubectl exec $POD_NAME -n $NAMESPACE -c app -- cat /vault/secrets/database.txt | grep DB_USERNAME | cut -d= -f2)
if [[ "$DB_USERNAME" == "db-admin" ]]; then
    print_success "Vault에서 Secret이 정상적으로 주입됨!"
else
    print_error "Secret 값이 예상과 다릅니다: $DB_USERNAME"
    exit 1
fi

# Pod 로그 확인
print_step "10. 애플리케이션 로그 확인"
kubectl logs $POD_NAME -n $NAMESPACE -c app | head -30

echo ""
echo "=========================================="
print_success "Vault Sidecar Agent Injector 테스트 완료!"
echo "=========================================="
echo ""
echo "요약:"
echo "  - vault-agent-init: Pod 시작 시 Secret 주입"
echo "  - vault-agent (sidecar): Secret 지속적 갱신"
echo "  - 템플릿으로 원하는 형식 지정 가능"
echo "  - 애플리케이션 코드 수정 없이 Secret 주입"
echo ""
echo "핵심 장점:"
echo "  - annotation만으로 Secret 주입 가능"
echo "  - Vault의 동적 Secret 자동 갱신"
echo "  - 다양한 템플릿 형식 지원 (env, json, yaml 등)"
