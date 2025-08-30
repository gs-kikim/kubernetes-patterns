#!/bin/bash

# Minikube 기반 Automated Placement 테스트 환경 설정 스크립트
# 3노드 Minikube 클러스터를 생성하고 테스트 환경을 구성합니다

set -e

echo "=============================================="
echo "Kubernetes Automated Placement Pattern"
echo "Minikube 테스트 환경 설정"
echo "=============================================="

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Minikube 설치 확인
if ! command -v minikube &> /dev/null; then
    echo -e "${RED}Minikube가 설치되어 있지 않습니다.${NC}"
    echo "설치 방법: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi

echo -e "${BLUE}현재 Minikube 버전:${NC}"
minikube version

# 기존 클러스터 확인
echo ""
if minikube status 2>/dev/null | grep -q "Running"; then
    echo -e "${YELLOW}기존 Minikube 클러스터가 실행 중입니다.${NC}"
    read -p "삭제하고 새로 생성하시겠습니까? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "기존 클러스터 삭제 중..."
        minikube delete
    else
        echo "기존 클러스터를 유지합니다."
        exit 0
    fi
fi

# Minikube 멀티노드 클러스터 생성
echo ""
echo -e "${BLUE}3노드 Minikube 클러스터 생성 중...${NC}"
echo "이 작업은 몇 분 정도 소요될 수 있습니다."

minikube start --nodes 3 \
    --cpus 2 \
    --memory 2048 \
    --kubernetes-version=v1.28.0 \
    --driver=docker

# 클러스터 상태 확인
echo ""
echo -e "${BLUE}클러스터 상태 확인${NC}"
minikube status

# Metrics Server 활성화
echo ""
echo -e "${BLUE}Metrics Server 활성화${NC}"
minikube addons enable metrics-server

echo -e "${GREEN}✓ Minikube 클러스터 생성 완료${NC}"

# 노드 확인
echo ""
echo -e "${BLUE}클러스터 노드 확인${NC}"
kubectl get nodes

# 노드 수 확인
node_count=$(kubectl get nodes --no-headers | wc -l)
if [ $node_count -lt 2 ]; then
    echo -e "${YELLOW}경고: 단일 노드 클러스터입니다. 일부 테스트가 제한될 수 있습니다.${NC}"
fi

# 노드 라벨링
echo ""
echo -e "${BLUE}노드 라벨링 시작${NC}"

# Minikube 노드 이름 가져오기
nodes=($(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'))
echo "발견된 노드: ${nodes[@]}"

# 각 노드에 Zone 라벨 추가
zones=("us-west-1a" "us-west-1b" "us-west-1c")
for i in "${!nodes[@]}"; do
    zone_index=$((i % 3))
    zone=${zones[$zone_index]}
    
    echo ""
    echo "노드 ${nodes[$i]}에 라벨 추가 중..."
    
    # Zone 라벨
    kubectl label node ${nodes[$i]} topology.kubernetes.io/zone=$zone --overwrite
    
    # 추가 라벨들
    if [ $i -eq 0 ]; then
        # 첫 번째 노드 (Control Plane)
        kubectl label node ${nodes[$i]} disktype=ssd --overwrite
        kubectl label node ${nodes[$i]} environment=production --overwrite
        kubectl label node ${nodes[$i]} node-type=compute-optimized --overwrite
        echo "  - disktype=ssd, environment=production, node-type=compute-optimized"
    elif [ $i -eq 1 ]; then
        # 두 번째 노드
        kubectl label node ${nodes[$i]} disktype=hdd --overwrite
        kubectl label node ${nodes[$i]} environment=staging --overwrite
        kubectl label node ${nodes[$i]} node-type=memory-optimized --overwrite
        echo "  - disktype=hdd, environment=staging, node-type=memory-optimized"
    else
        # 세 번째 노드
        kubectl label node ${nodes[$i]} disktype=ssd --overwrite
        kubectl label node ${nodes[$i]} environment=development --overwrite
        kubectl label node ${nodes[$i]} node-type=general-purpose --overwrite
        echo "  - disktype=ssd, environment=development, node-type=general-purpose"
    fi
    
    # Rack 라벨 (데이터센터 시뮬레이션)
    rack_num=$((i / 2 + 1))
    kubectl label node ${nodes[$i]} topology.kubernetes.io/rack=rack-$rack_num --overwrite
    echo "  - Zone: $zone, Rack: rack-$rack_num"
done

echo ""
echo -e "${GREEN}✓ 노드 라벨링 완료${NC}"

# Taint 설정 (선택적)
echo ""
echo -e "${YELLOW}선택적 Taint 설정${NC}"
echo "세 번째 노드를 특수 목적 노드로 설정할 수 있습니다."
read -p "세 번째 노드에 GPU Taint를 설정하시겠습니까? [y/N]: " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ ${#nodes[@]} -ge 3 ]; then
        # 세 번째 노드를 GPU 노드로 설정
        kubectl taint nodes ${nodes[2]} gpu=true:NoSchedule --overwrite
        kubectl label node ${nodes[2]} accelerator=gpu --overwrite
        echo -e "${GREEN}✓ ${nodes[2]}를 GPU 노드로 설정${NC}"
    else
        echo -e "${YELLOW}3개 미만의 노드로는 GPU 노드를 설정할 수 없습니다.${NC}"
    fi
fi

# 최종 노드 상태 확인
echo ""
echo -e "${BLUE}최종 노드 상태${NC}"
echo ""
echo "노드 목록 및 라벨:"
kubectl get nodes --show-labels

echo ""
echo "노드 Taints:"
for node in "${nodes[@]}"; do
    echo -e "${YELLOW}$node:${NC}"
    kubectl describe node $node | grep -A 5 "Taints:" | head -6
done

# 테스트 준비 완료
echo ""
echo "=============================================="
echo -e "${GREEN}테스트 환경 설정 완료!${NC}"
echo "=============================================="
echo ""
echo "다음 명령으로 테스트를 실행할 수 있습니다:"
echo "  ./test-placement.sh"
echo ""
echo "클러스터 정보:"
echo "  - 노드 수: $node_count"
echo "  - 클러스터 타입: Minikube"
echo "  - 프로파일: default"
echo ""
echo "개별 예제 실행:"
echo "  kubectl apply -f node-selector.yml"
echo "  kubectl apply -f node-affinity.yml"
echo "  kubectl apply -f pod-affinity.yml"
echo "  kubectl apply -f taints-tolerations.yml"
echo "  kubectl apply -f topology-spread.yml"
echo ""
echo "클러스터를 삭제하려면:"
echo "  minikube delete"