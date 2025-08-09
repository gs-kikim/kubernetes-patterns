#!/bin/bash

# FluxCD Installation Script for Local Minikube
# This script installs FluxCD without GitHub integration for local testing

set -e

echo "Minikube cluster에 FluxCD를 설치하는 중..."

# Check if cluster is ready
kubectl cluster-info &> /dev/null || {
    echo "[ERROR] Kubernetes cluster에 접근할 수 없습니다. 먼저 setup-minikube.sh를 실행하세요."
    exit 1
}

# Install Flux components
echo "Flux 컴포넌트를 설치하는 중..."
flux install \
  --namespace=flux-system \
  --network-policy=false \
  --components=source-controller,kustomize-controller,helm-controller,notification-controller

# Wait for Flux to be ready
echo "Flux 컴포넌트가 준비될 때까지 기다리는 중..."
kubectl -n flux-system wait deployment --all --for=condition=Available --timeout=5m

# Create a Git source for local testing (using a sample repo)
echo "샘플 Git source repository를 생성하는 중..."
cat <<EOF | kubectl apply -f -
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: local-repo
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/k8spatterns/examples.git
  ref:
    branch: main
EOF

# Verify installation
echo "FluxCD 설치를 검증하는 중..."
flux check

echo "FluxCD가 성공적으로 설치되었습니다!"
echo ""
echo "FluxCD가 현재 Minikube cluster에서 실행 중입니다"
echo "Kustomization과 HelmRelease를 사용하여 애플리케이션을 배포할 수 있습니다"