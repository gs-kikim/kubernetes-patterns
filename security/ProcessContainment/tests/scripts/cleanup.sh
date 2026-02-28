#!/bin/bash
# 테스트 환경 정리 스크립트

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$SCRIPT_DIR/.."

echo "=========================================="
echo "Process Containment 테스트 리소스 정리"
echo "=========================================="
echo ""

echo "1. SecurityContext 테스트 리소스 삭제..."
kubectl delete -f "$TEST_ROOT/1-security-context/" --ignore-not-found=true

echo "2. Capabilities 테스트 리소스 삭제..."
kubectl delete -f "$TEST_ROOT/2-capabilities/" --ignore-not-found=true

echo "3. Filesystem 테스트 리소스 삭제..."
kubectl delete -f "$TEST_ROOT/3-filesystem/" --ignore-not-found=true

echo "4. Pod Security Standards 테스트 리소스 삭제..."
kubectl delete -f "$TEST_ROOT/4-pod-security-standards/" -n pss-privileged --ignore-not-found=true 2>/dev/null || true
kubectl delete -f "$TEST_ROOT/4-pod-security-standards/" -n pss-baseline --ignore-not-found=true 2>/dev/null || true
kubectl delete -f "$TEST_ROOT/4-pod-security-standards/" -n pss-restricted --ignore-not-found=true 2>/dev/null || true
kubectl delete namespace pss-privileged pss-baseline pss-restricted --ignore-not-found=true

echo "5. Seccomp 테스트 리소스 삭제..."
kubectl delete -f "$TEST_ROOT/5-seccomp/" --ignore-not-found=true

echo "6. 통합 테스트 리소스 삭제..."
kubectl delete -f "$TEST_ROOT/7-integration/" --ignore-not-found=true

echo ""
echo "=========================================="
echo "정리 완료!"
echo "=========================================="
echo ""
echo "남아있는 테스트 관련 Pod 확인:"
kubectl get pods -l test --all-namespaces 2>/dev/null || echo "없음"
