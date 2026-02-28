#!/bin/bash
# Secure Configuration 전체 테스트 리소스 정리

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/.."

echo "=========================================="
echo "Secure Configuration 테스트 리소스 정리"
echo "=========================================="
echo ""

# 각 솔루션별 cleanup 실행
echo ">>> Sealed Secrets 정리"
bash "$BASE_DIR/01-sealed-secrets/tests/cleanup.sh" 2>/dev/null || true

echo ">>> sops 정리"
bash "$BASE_DIR/02-sops/tests/cleanup.sh" 2>/dev/null || true

echo ">>> External Secrets 정리"
bash "$BASE_DIR/03-external-secrets/tests/cleanup.sh" 2>/dev/null || true

echo ">>> CSI Driver 테스트 정리"
bash "$BASE_DIR/04-secrets-store-csi/tests/cleanup.sh" 2>/dev/null || true

echo ">>> Vault Sidecar 테스트 정리"
bash "$BASE_DIR/05-vault-sidecar/tests/cleanup.sh" 2>/dev/null || true

# 임시 파일 정리
rm -f /tmp/sealed-secret.yaml /tmp/encrypted-secret.enc.yaml /tmp/decrypted-secret.yaml

echo ""
echo "=========================================="
echo "정리 완료!"
echo "=========================================="
echo ""
echo "주의: Sealed Secrets Controller, ESO, Vault는 삭제되지 않았습니다."
echo "완전히 제거하려면:"
echo "  helm uninstall sealed-secrets -n sealed-secrets"
echo "  helm uninstall external-secrets -n external-secrets"
echo "  helm uninstall vault -n vault"
echo "  helm uninstall csi-secrets-store -n kube-system"
