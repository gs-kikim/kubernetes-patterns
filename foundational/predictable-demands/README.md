# Predictable Demands Pattern Examples

이 디렉토리는 Kubernetes의 Predictable Demands 패턴에 대한 실습 예제를 포함합니다.

## 📋 목차

1. [01-runtime-dependencies](./01-runtime-dependencies) - 런타임 의존성 관리
2. [02-resource-profiles](./02-resource-profiles) - 리소스 프로파일 설정
3. [03-pod-priority](./03-pod-priority) - Pod 우선순위 관리
4. [04-project-resources](./04-project-resources) - 프로젝트 리소스 관리
5. [05-testing](./05-testing) - 테스트 스크립트 및 검증

## 🎯 학습 목표

- Kubernetes에서 애플리케이션의 리소스 요구사항 선언하기
- QoS 클래스 이해 및 적용
- Pod 우선순위와 선점 메커니즘 활용
- ResourceQuota와 LimitRange로 네임스페이스 리소스 관리

## 🚀 시작하기

### 사전 요구사항

- Minikube (1.30+ 권장)
- kubectl 명령어 도구
- Docker 또는 Podman
- 최소 4GB RAM, 2 CPU cores

### Minikube 시작

```bash
# Minikube 시작 (충분한 리소스 할당)
minikube start --cpus=2 --memory=4096 --driver=docker

# 애드온 활성화
minikube addons enable metrics-server
minikube addons enable dashboard

# 상태 확인
minikube status
kubectl get nodes
```

### 메트릭 서버 확인

```bash
# Minikube에서는 애드온으로 설치됨
kubectl get deployment metrics-server -n kube-system

# 메트릭 확인
kubectl top nodes
kubectl top pods --all-namespaces
```

### 예제 실행 순서

1. **런타임 의존성 이해**: `01-runtime-dependencies`의 예제로 시작
2. **리소스 프로파일 설정**: `02-resource-profiles`에서 QoS 클래스 실습
3. **우선순위 관리**: `03-pod-priority`에서 선점 메커니즘 확인
4. **프로젝트 리소스**: `04-project-resources`에서 네임스페이스 관리
5. **테스트 실행**: `05-testing`의 스크립트로 검증

## 📊 주요 개념

### QoS (Quality of Service) 클래스

- **Guaranteed**: requests = limits (최고 우선순위)
- **Burstable**: requests < limits (중간 우선순위)
- **Best-Effort**: 리소스 정의 없음 (최저 우선순위)

### 리소스 유형

- **압축 가능**: CPU, 네트워크 (throttling 가능)
- **압축 불가능**: 메모리, 스토리지 (OOM 발생 가능)

## 📝 참고 자료

- [Kubernetes 공식 문서 - Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Kubernetes Patterns 책](https://www.oreilly.com/library/view/kubernetes-patterns/9781492050285/)