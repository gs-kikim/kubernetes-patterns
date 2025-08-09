#!/bin/bash

# Cleanup script for all deployments

echo "모든 테스트 deployment와 resource를 정리하는 중..."

# Delete application namespaces
echo "애플리케이션 namespace를 삭제하는 중..."
kubectl delete namespace rolling-demo --ignore-not-found=true
kubectl delete namespace blue-green-demo --ignore-not-found=true
kubectl delete namespace canary-demo --ignore-not-found=true

# Delete Flux Kustomizations
echo "Flux Kustomization을 삭제하는 중..."
kubectl delete kustomization -n flux-system rolling-update-app --ignore-not-found=true
kubectl delete kustomization -n flux-system blue-green-app --ignore-not-found=true
kubectl delete kustomization -n flux-system canary-app --ignore-not-found=true

# Optional: Uninstall Flagger
read -p "Flagger를 제거하시겠습니까? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete namespace flagger-system --ignore-not-found=true
fi

# Optional: Uninstall FluxCD
read -p "FluxCD를 제거하시겠습니까? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    flux uninstall --namespace=flux-system --silent
fi

# Optional: Stop Minikube
read -p "Minikube를 중지하시겠습니까? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    minikube stop
fi

echo "정리가 성공적으로 완료되었습니다!"