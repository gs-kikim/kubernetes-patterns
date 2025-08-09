#!/bin/bash

# Test script for Rolling Update deployment

set -e

echo "Rolling Update 배포 전략을 테스트하는 중..."

# Apply the Flux Kustomization
echo "Rolling Update 설정을 cluster에 적용하는 중..."
kubectl apply -f apps/rolling-update/flux-kustomization.yaml

# Wait for deployment
echo "Deployment가 준비될 때까지 기다리는 중..."
kubectl -n rolling-demo wait deployment random-generator --for=condition=Available --timeout=3m

# Show initial state
echo "초기 deployment 상태:"
kubectl -n rolling-demo get deployment random-generator
kubectl -n rolling-demo get pods -l app=random-generator

# Port forward for testing
echo "8080 포트로 port forwarding 설정 중 (background 실행)..."
kubectl -n rolling-demo port-forward svc/random-generator 8080:80 &
PF_PID=$!
sleep 3

# Test the application
echo "애플리케이션 endpoint를 테스트하는 중..."
curl -s http://localhost:8080/actuator/info | jq '.' || echo "앱이 응답하고 있습니다"

# Simulate rolling update
echo ""
echo "Version 2.0으로 rolling update를 시뮬레이션하는 중..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: random-generator
  namespace: rolling-demo
spec:
  template:
    spec:
      containers:
      - name: random-generator
        image: k8spatterns/random-generator:2.0
        ports:
        - containerPort: 8080
        env:
        - name: PATTERN
          value: "Rolling Update v2"
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
EOF

# Watch the rolling update
echo "Rolling update 진행 상황을 모니터링하는 중..."
kubectl -n rolling-demo rollout status deployment/random-generator --timeout=3m

# Show final state
echo "업데이트 후 최종 deployment 상태:"
kubectl -n rolling-demo get deployment random-generator
kubectl -n rolling-demo get pods -l app=random-generator

# Cleanup port forwarding
kill $PF_PID 2>/dev/null || true

echo "[SUCCESS] Rolling Update 테스트 완료!"
echo ""
echo "[TIP] Do you want to Rollback: kubectl -n rolling-demo rollout undo deployment/random-generator"