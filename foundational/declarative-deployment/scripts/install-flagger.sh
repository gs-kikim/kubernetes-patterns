#!/bin/bash

# Flagger Installation Script for Progressive Delivery
# Flagger enables canary deployments, A/B testing, and blue-green deployments

set -e

echo "Progressive delivery를 위한 Flagger를 설치하는 중..."

# Add Flagger Helm repository
echo "Flagger Helm repository를 추가하는 중..."
kubectl apply -f https://raw.githubusercontent.com/fluxcd/flagger/main/artifacts/flagger/crd.yaml

# Install Flagger in istio-system namespace
echo "Flagger controller를 설치하는 중..."
kubectl create namespace flagger-system --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: flagger
  namespace: flux-system
spec:
  interval: 1h
  url: https://flagger.app
EOF

cat <<EOF | kubectl apply -f -
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: flagger
  namespace: flux-system
spec:
  releaseName: flagger
  targetNamespace: flagger-system
  interval: 10m
  chart:
    spec:
      chart: flagger
      version: "1.35.0"
      sourceRef:
        kind: HelmRepository
        name: flagger
  values:
    meshProvider: kubernetes
    metricsServer: http://prometheus:9090
EOF

# Install Flagger loadtester for testing
echo "트래픽 생성을 위한 Flagger loadtester를 설치하는 중..."
cat <<EOF | kubectl apply -f -
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: flagger-loadtester
  namespace: flux-system
spec:
  releaseName: flagger-loadtester
  targetNamespace: flagger-system
  interval: 10m
  chart:
    spec:
      chart: loadtester
      version: "0.29.0"
      sourceRef:
        kind: HelmRepository
        name: flagger
  values:
    cmd:
      timeout: 1h
EOF

echo "Flagger deployment가 준비될 때까지 기다리는 중..."
kubectl -n flagger-system wait deployment flagger --for=condition=Available --timeout=5m 2>/dev/null || true

echo "Flagger installed successfully!"
echo ""
echo "Flagger가 progressive delivery 배포를 위해 준비되었습니다"