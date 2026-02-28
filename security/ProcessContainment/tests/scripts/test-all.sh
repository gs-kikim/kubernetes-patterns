#!/bin/bash
# Process Containment 전체 테스트 실행 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Process Containment 전체 테스트 시작"
echo "=========================================="
echo ""

START_TIME=$(date +%s)

# 1. SecurityContext 테스트
echo ">>> 1/5: SecurityContext 테스트"
bash "$SCRIPT_DIR/test-security-context.sh"
echo ""

# 2. Capabilities 테스트
echo ">>> 2/5: Capabilities 테스트"
bash "$SCRIPT_DIR/test-capabilities.sh"
echo ""

# 3. Filesystem 테스트
echo ">>> 3/5: Filesystem 보안 테스트"
bash "$SCRIPT_DIR/test-filesystem.sh"
echo ""

# 4. Pod Security Standards 테스트
echo ">>> 4/5: Pod Security Standards 테스트"
bash "$SCRIPT_DIR/test-pss.sh"
echo ""

# 5. 통합 테스트
echo ">>> 5/5: 통합 테스트"
bash "$SCRIPT_DIR/test-integration.sh"
echo ""

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "=========================================="
echo "전체 테스트 완료!"
echo "=========================================="
echo "소요 시간: ${DURATION}초"
echo ""
echo "모든 리소스를 정리하려면:"
echo "  bash $SCRIPT_DIR/cleanup.sh"
