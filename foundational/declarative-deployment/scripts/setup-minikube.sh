#!/bin/bash

# Minikube Setup Script for FluxCD Testing
# Requirements: minikube, kubectl, flux CLI

set -e

echo "FluxCD 테스트를 위한 Minikube 환경을 설정하는 중..."

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "[ERROR] Minikube가 설치되어 있지 않습니다. 먼저 설치해주세요."
    echo "Visit: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "[ERROR] kubectl이 설치되어 있지 않습니다. 먼저 설치해주세요."
    exit 1
fi

# Start minikube if not running
if ! minikube status &> /dev/null; then
    echo "Minikube cluster를 시작하는 중..."
    minikube start --cpus=4 --memory=8192 --kubernetes-version=v1.28.0
else
    echo "Minikube가 이미 실행 중입니다"
fi

# Enable required addons
echo "필수 Minikube addon들을 활성화하는 중..."
minikube addons enable metrics-server
minikube addons enable ingress

# Install Flux CLI if not installed
if ! command -v flux &> /dev/null; then
    echo "Flux CLI를 설치하는 중..."
    curl -s https://fluxcd.io/install.sh | sudo bash
else
    echo "Flux CLI가 이미 설치되어 있습니다"
fi

# Check Flux prerequisites
echo "Flux 사전 요구사항을 확인하는 중..."
flux check --pre

echo "[SUCCESS] FluxCD를 위한 Minikube 환경이 준비되었습니다!"
echo ""
echo "다음 단계:"
echo "1. FluxCD 설치: ./scripts/install-fluxcd.sh 실행"
echo "2. 배포 스크립트를 사용하여 샘플 애플리케이션 배포"