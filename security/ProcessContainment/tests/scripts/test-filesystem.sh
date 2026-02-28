#!/bin/bash
# Filesystem 보안 테스트 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/../3-filesystem"

echo "=========================================="
echo "Filesystem 보안 테스트 시작"
echo "=========================================="
echo ""

# Test 1: readOnlyRootFilesystem (실패 케이스)
echo "[Test 1] readOnlyRootFilesystem 실패 케이스"
echo "→ nginx가 필요한 디렉토리에 쓰기 실패로 시작 불가 예상"
kubectl apply -f "$TEST_DIR/01-readonly-fail.yaml"

echo "→ Pod 상태 확인 중 (30초 대기)..."
sleep 30

POD_STATUS=$(kubectl get pod readonly-fail -o jsonpath='{.status.phase}')
CONTAINER_STATUS=$(kubectl get pod readonly-fail -o jsonpath='{.status.containerStatuses[0].state}' 2>/dev/null || echo "{}")

if echo "$CONTAINER_STATUS" | grep -q "waiting\|terminated"; then
    echo "✓ PASS: Pod가 실패함 (예상된 결과)"
    echo "  상태: $POD_STATUS"
    kubectl logs readonly-fail 2>&1 | head -10 || echo "  (로그 없음)"
else
    echo "✗ FAIL: Pod가 실행 중 (예상하지 못한 결과)"
fi
echo ""

# Test 2: readOnlyRootFilesystem + emptyDir 볼륨
echo "[Test 2] readOnlyRootFilesystem + emptyDir 볼륨"
kubectl apply -f "$TEST_DIR/02-readonly-with-volumes.yaml"
kubectl wait --for=condition=Ready pod/readonly-success --timeout=60s

echo "→ 루트 파일시스템 쓰기 테스트 (실패 예상)..."
if kubectl exec readonly-success -- touch /test.txt 2>&1 | grep -q "Read-only file system"; then
    echo "✓ PASS: 루트 파일시스템 쓰기 차단됨"
else
    echo "✗ FAIL: 루트 파일시스템 쓰기 허용됨"
fi

echo "→ /tmp 디렉토리 쓰기 테스트 (성공 예상)..."
if kubectl exec readonly-success -- touch /tmp/test.txt 2>/dev/null; then
    echo "✓ PASS: emptyDir 볼륨 쓰기 성공"
else
    echo "✗ FAIL: emptyDir 볼륨 쓰기 실패"
fi
echo ""

# Test 3: 완전 불변 컨테이너
echo "[Test 3] 완전 불변 컨테이너"
kubectl apply -f "$TEST_DIR/03-immutable-container.yaml"
kubectl wait --for=condition=Ready pod/immutable-container --timeout=30s

echo "→ 불변성 테스트 결과:"
kubectl logs immutable-container
echo ""

echo "=========================================="
echo "Filesystem 보안 테스트 완료"
echo "=========================================="
echo ""
echo "정리하려면: kubectl delete -f $TEST_DIR/"
