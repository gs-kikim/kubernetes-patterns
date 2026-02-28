#!/bin/bash
# SecurityContext 기본 테스트 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/../1-security-context"

echo "=========================================="
echo "SecurityContext 기본 테스트 시작"
echo "=========================================="
echo ""

# Test 1: runAsNonRoot (실패 예상)
echo "[Test 1] runAsNonRoot 테스트"
echo "→ nginx 이미지는 기본적으로 root로 실행되므로 실패 예상"
if kubectl apply -f "$TEST_DIR/01-run-as-non-root.yaml" 2>&1 | grep -q "is forbidden"; then
    echo "✓ PASS: runAsNonRoot 차단이 작동함"
else
    echo "⚠ WARNING: Pod가 생성되었지만 곧 실패할 것임"
    kubectl wait --for=condition=Ready pod/non-root-test --timeout=10s 2>/dev/null && \
        echo "✗ FAIL: Pod가 실행됨 (예상하지 못한 결과)" || \
        echo "✓ PASS: Pod가 실패함 (예상된 결과)"
    kubectl delete -f "$TEST_DIR/01-run-as-non-root.yaml" --ignore-not-found=true
fi
echo ""

# Test 2: runAsUser 명시적 설정
echo "[Test 2] runAsUser/runAsGroup 설정 테스트"
kubectl apply -f "$TEST_DIR/02-run-as-user.yaml"
kubectl wait --for=condition=Ready pod/run-as-user-test --timeout=30s

echo "→ 사용자 ID 확인 중..."
USER_ID=$(kubectl exec run-as-user-test -- id -u)
GROUP_ID=$(kubectl exec run-as-user-test -- id -g)

if [ "$USER_ID" = "1000" ] && [ "$GROUP_ID" = "2000" ]; then
    echo "✓ PASS: UID=$USER_ID, GID=$GROUP_ID (예상: UID=1000, GID=2000)"
else
    echo "✗ FAIL: UID=$USER_ID, GID=$GROUP_ID (예상: UID=1000, GID=2000)"
fi
echo ""

# Test 3: fsGroup 설정
echo "[Test 3] fsGroup 설정 테스트"
kubectl apply -f "$TEST_DIR/03-fs-group.yaml"
kubectl wait --for=condition=Ready pod/fs-group-test --timeout=30s

echo "→ 볼륨 그룹 소유권 확인 중..."
VOLUME_GROUP=$(kubectl exec fs-group-test -- ls -ld /data | awk '{print $4}')

if [ "$VOLUME_GROUP" = "3000" ]; then
    echo "✓ PASS: 볼륨 그룹=$VOLUME_GROUP (예상: 3000)"
else
    echo "✗ FAIL: 볼륨 그룹=$VOLUME_GROUP (예상: 3000)"
fi
echo ""

# Test 4: allowPrivilegeEscalation 차단
echo "[Test 4] allowPrivilegeEscalation 차단 테스트"
kubectl apply -f "$TEST_DIR/04-privilege-escalation.yaml"
kubectl wait --for=condition=Ready pod/no-privilege-escalation-test --timeout=30s

echo "→ NoNewPrivs 플래그 확인 중..."
NO_NEW_PRIVS=$(kubectl exec no-privilege-escalation-test -- cat /proc/1/status | grep NoNewPrivs | awk '{print $2}')

if [ "$NO_NEW_PRIVS" = "1" ]; then
    echo "✓ PASS: NoNewPrivs=$NO_NEW_PRIVS (권한 상승 차단됨)"
else
    echo "✗ FAIL: NoNewPrivs=$NO_NEW_PRIVS (권한 상승 허용됨)"
fi
echo ""

echo "=========================================="
echo "SecurityContext 기본 테스트 완료"
echo "=========================================="
echo ""
echo "정리하려면: kubectl delete -f $TEST_DIR/"
