#!/bin/bash
# CSI Driver 테스트 리소스 정리

NAMESPACE="csi-test"

echo "CSI Driver 테스트 리소스 정리 중..."

kubectl delete namespace $NAMESPACE --ignore-not-found=true

echo "정리 완료!"
