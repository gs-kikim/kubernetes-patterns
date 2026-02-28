#!/bin/bash
# Capabilities 테스트 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/../2-capabilities"

echo "=========================================="
echo "Capabilities 테스트 시작"
echo "=========================================="
echo ""

# Test 1: 모든 Capabilities 제거
echo "[Test 1] 모든 Capabilities 제거 테스트"
kubectl apply -f "$TEST_DIR/01-drop-all.yaml"
kubectl wait --for=condition=Ready pod/drop-all-caps --timeout=30s

echo "→ Capabilities 확인 중..."
CAP_EFF=$(kubectl exec drop-all-caps -- cat /proc/1/status | grep CapEff | awk '{print $2}')

if [ "$CAP_EFF" = "0000000000000000" ]; then
    echo "✓ PASS: CapEff=$CAP_EFF (모든 capabilities 제거됨)"
else
    echo "⚠ WARNING: CapEff=$CAP_EFF (일부 capabilities가 남아있음)"
fi
echo ""

# Test 2: NET_BIND_SERVICE Capability 추가
echo "[Test 2] NET_BIND_SERVICE Capability 추가 테스트"
kubectl apply -f "$TEST_DIR/02-add-net-bind.yaml"
kubectl wait --for=condition=Ready pod/net-bind-caps --timeout=30s

echo "→ 포트 80 바인딩 확인 중..."
sleep 3  # 서버 시작 대기

if kubectl logs net-bind-caps 2>&1 | grep -q "Serving HTTP"; then
    echo "✓ PASS: 포트 80 바인딩 성공 (NET_BIND_SERVICE 작동)"
else
    echo "⚠ WARNING: 서버 시작 확인 필요"
    kubectl logs net-bind-caps
fi

echo "→ Capabilities 값 확인..."
kubectl exec net-bind-caps -- cat /proc/1/status | grep Cap
echo ""

# Test 3: Privileged 컨테이너 (비교용)
echo "[Test 3] Privileged 컨테이너 테스트 (비교용)"
kubectl apply -f "$TEST_DIR/03-privileged.yaml"
kubectl wait --for=condition=Ready pod/privileged-container --timeout=30s

echo "→ Capabilities 확인 중..."
kubectl exec privileged-container -- cat /proc/1/status | grep CapEff

echo "⚠ WARNING: Privileged 컨테이너는 모든 권한을 가지므로 매우 위험함!"
echo ""

# Test 4: Capabilities 검증 도구
echo "[Test 4] Capabilities 검증 도구 실행"
kubectl apply -f "$TEST_DIR/04-verify-caps.yaml"
kubectl wait --for=condition=Ready pod/cap-verify --timeout=60s

echo "→ Capabilities 상세 정보:"
kubectl logs cap-verify
echo ""

echo "=========================================="
echo "Capabilities 테스트 완료"
echo "=========================================="
echo ""
echo "정리하려면: kubectl delete -f $TEST_DIR/"
