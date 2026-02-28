#!/bin/bash
# Secure Configuration 전체 테스트 실행 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/.."

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "Secure Configuration 전체 테스트 시작"
echo "=========================================="
echo ""

START_TIME=$(date +%s)
FAILED_TESTS=""

run_test() {
    local name=$1
    local script=$2

    echo ">>> $name"
    echo "----------------------------------------"

    if bash "$script"; then
        echo -e "${GREEN}[PASS]${NC} $name"
    else
        echo -e "${RED}[FAIL]${NC} $name"
        FAILED_TESTS="$FAILED_TESTS\n  - $name"
    fi
    echo ""
}

# 1. Sealed Secrets 테스트
echo "=========================================="
echo ">>> 1/5: Sealed Secrets 테스트"
echo "=========================================="
run_test "Sealed Secrets" "$BASE_DIR/01-sealed-secrets/tests/test-seal-unseal.sh"

# 2. sops + age 테스트
echo "=========================================="
echo ">>> 2/5: sops + age 테스트"
echo "=========================================="
run_test "sops + age" "$BASE_DIR/02-sops/tests/test-encrypt-decrypt.sh"

# 3. External Secrets Operator 테스트
echo "=========================================="
echo ">>> 3/5: External Secrets Operator 테스트"
echo "=========================================="
run_test "External Secrets Operator" "$BASE_DIR/03-external-secrets/tests/test-fake-provider.sh"

# 4. Vault 설치 (CSI, Sidecar 테스트용)
echo "=========================================="
echo ">>> Vault 설치 확인"
echo "=========================================="
if ! kubectl get pod vault-0 -n vault &>/dev/null; then
    echo "Vault 설치 중..."
    bash "$BASE_DIR/00-setup/02-install-vault.sh"
else
    echo "Vault가 이미 설치되어 있습니다."
fi
echo ""

# 5. Secrets Store CSI Driver 테스트
echo "=========================================="
echo ">>> 4/5: Secrets Store CSI Driver 테스트"
echo "=========================================="
run_test "Secrets Store CSI Driver" "$BASE_DIR/04-secrets-store-csi/tests/test-volume-mount.sh"

# 6. Vault Sidecar Injector 테스트
echo "=========================================="
echo ">>> 5/5: Vault Sidecar Injector 테스트"
echo "=========================================="
run_test "Vault Sidecar Injector" "$BASE_DIR/05-vault-sidecar/tests/test-sidecar-injection.sh"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "=========================================="
echo "전체 테스트 완료!"
echo "=========================================="
echo "소요 시간: ${DURATION}초"
echo ""

if [[ -n "$FAILED_TESTS" ]]; then
    echo -e "${RED}실패한 테스트:${NC}$FAILED_TESTS"
    echo ""
    exit 1
else
    echo -e "${GREEN}모든 테스트 통과!${NC}"
fi

echo ""
echo "모든 리소스를 정리하려면:"
echo "  bash $SCRIPT_DIR/cleanup-all.sh"
