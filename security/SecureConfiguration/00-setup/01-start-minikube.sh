#!/bin/bash
# minikube 시작 스크립트

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "${YELLOW}[STEP]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

echo "=========================================="
echo "minikube 환경 시작"
echo "=========================================="
echo ""

# minikube 상태 확인
print_step "minikube 상태 확인"
STATUS=$(minikube status -f '{{.Host}}' 2>/dev/null || echo "Stopped")

if [[ "$STATUS" == "Running" ]]; then
    echo "  minikube가 이미 실행 중입니다."
else
    print_step "minikube 시작 (8GB RAM, 4 CPU)"
    minikube start --memory=8192 --cpus=4 --driver=docker
fi

print_step "클러스터 정보 확인"
kubectl cluster-info
echo ""
kubectl get nodes

print_success "minikube 환경 준비 완료!"
