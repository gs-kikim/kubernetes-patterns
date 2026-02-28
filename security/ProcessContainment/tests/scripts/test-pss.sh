#!/bin/bash
# Pod Security Standards 테스트 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/../4-pod-security-standards"

echo "=========================================="
echo "Pod Security Standards 테스트 시작"
echo "=========================================="
echo ""

# 네임스페이스 생성
echo "[Setup] PSS 네임스페이스 생성"
kubectl apply -f "$TEST_DIR/namespaces/"
echo ""

# Test 1: Privileged Pod (baseline에서 거부되어야 함)
echo "[Test 1] Privileged Pod 테스트"
echo "→ pss-privileged 네임스페이스에 배포 (성공 예상)"
if kubectl apply -f "$TEST_DIR/01-privileged-pod.yaml" -n pss-privileged; then
    echo "✓ PASS: privileged 네임스페이스에서 생성 성공"
    kubectl wait --for=condition=Ready pod/privileged-pod -n pss-privileged --timeout=30s
else
    echo "✗ FAIL: privileged 네임스페이스에서 생성 실패"
fi

echo ""
echo "→ pss-baseline 네임스페이스에 배포 (실패 예상)"
if kubectl apply -f "$TEST_DIR/01-privileged-pod.yaml" -n pss-baseline 2>&1 | grep -q "violates PodSecurity"; then
    echo "✓ PASS: baseline 네임스페이스에서 생성 거부됨"
else
    echo "✗ FAIL: baseline 네임스페이스에서 생성 허용됨 (예상하지 못한 결과)"
fi
echo ""

# Test 2: Baseline Pod (baseline에서 허용, restricted에서 경고)
echo "[Test 2] Baseline Pod 테스트"
echo "→ pss-baseline 네임스페이스에 배포 (경고와 함께 성공 예상)"
if kubectl apply -f "$TEST_DIR/02-baseline-pod.yaml" -n pss-baseline 2>&1; then
    echo "✓ PASS: baseline 네임스페이스에서 생성 성공 (restricted 경고 표시됨)"
    kubectl wait --for=condition=Ready pod/baseline-pod -n pss-baseline --timeout=30s
else
    echo "✗ FAIL: baseline 네임스페이스에서 생성 실패"
fi

echo ""
echo "→ pss-restricted 네임스페이스에 배포 (실패 예상)"
if kubectl apply -f "$TEST_DIR/02-baseline-pod.yaml" -n pss-restricted 2>&1 | grep -q "violates PodSecurity"; then
    echo "✓ PASS: restricted 네임스페이스에서 생성 거부됨"
else
    echo "✗ FAIL: restricted 네임스페이스에서 생성 허용됨"
fi
echo ""

# Test 3: Restricted Pod (모든 네임스페이스에서 허용)
echo "[Test 3] Restricted Pod 테스트"
echo "→ pss-restricted 네임스페이스에 배포 (성공 예상)"
if kubectl apply -f "$TEST_DIR/03-restricted-pod.yaml" -n pss-restricted; then
    echo "✓ PASS: restricted 네임스페이스에서 생성 성공"
    kubectl wait --for=condition=Ready pod/restricted-pod -n pss-restricted --timeout=30s
else
    echo "✗ FAIL: restricted 네임스페이스에서 생성 실패"
fi

echo ""
echo "→ pss-baseline 네임스페이스에 배포 (성공 예상)"
if kubectl apply -f "$TEST_DIR/03-restricted-pod.yaml" -n pss-baseline; then
    echo "✓ PASS: baseline 네임스페이스에서도 생성 성공"
else
    echo "✗ FAIL: baseline 네임스페이스에서 생성 실패"
fi
echo ""

# Test 4: HostPath 볼륨 (restricted에서 거부)
echo "[Test 4] HostPath 볼륨 테스트"
echo "→ pss-baseline 네임스페이스에 배포 (성공 예상)"
if kubectl apply -f "$TEST_DIR/04-hostpath-pod.yaml" -n pss-baseline; then
    echo "✓ PASS: baseline 네임스페이스에서 생성 성공 (hostPath 허용)"
    kubectl wait --for=condition=Ready pod/hostpath-pod -n pss-baseline --timeout=30s
else
    echo "✗ FAIL: baseline 네임스페이스에서 생성 실패"
fi

echo ""
echo "→ pss-restricted 네임스페이스에 배포 (실패 예상)"
if kubectl apply -f "$TEST_DIR/04-hostpath-pod.yaml" -n pss-restricted 2>&1 | grep -q "violates PodSecurity"; then
    echo "✓ PASS: restricted 네임스페이스에서 생성 거부됨 (hostPath 차단)"
else
    echo "✗ FAIL: restricted 네임스페이스에서 생성 허용됨"
fi
echo ""

echo "=========================================="
echo "Pod Security Standards 테스트 완료"
echo "=========================================="
echo ""
echo "정리하려면:"
echo "  kubectl delete namespace pss-privileged pss-baseline pss-restricted"
