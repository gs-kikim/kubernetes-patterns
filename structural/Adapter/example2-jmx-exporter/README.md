# Example 2: JMX Exporter Adapter

## 개요

레거시 Java 애플리케이션의 JMX 메트릭을 Prometheus 형식으로 변환하는 실무 예제입니다.

**실무 시나리오**:
- 기존 Java 애플리케이션은 JMX로만 메트릭 노출
- Prometheus 모니터링 시스템 도입
- 애플리케이션 코드 수정 불가 (레거시)

## 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                         Pod                             │
│  ┌─────────────────┐    ┌─────────────────────────┐    │
│  │ Java App        │    │ JMX Exporter            │    │
│  │                 │    │ Adapter                 │    │
│  │ JMX MBeans     │───▶│                         │───▶│ Prometheus
│  │ :9010 (RMI)    │    │ :5556/metrics           │    │
│  │                 │    │ (HTTP)                  │    │
│  └─────────────────┘    └─────────────────────────┘    │
│         ▲                        │                      │
│         └────────────────────────┘                      │
│           localhost network                             │
└─────────────────────────────────────────────────────────┘
```

## 구성 요소

1. **SimpleJavaApp**: JMX MBean으로 메트릭 노출
   - RequestCount
   - ErrorCount
   - LastResponseTime
   - ErrorRate

2. **JMX Exporter**: JMX → Prometheus 변환
   - Bitnami JMX Exporter 이미지 사용
   - ConfigMap으로 매핑 규칙 정의

## 배포 방법

### 1. 이미지 빌드

```bash
docker build -t k8spatterns/simple-java-app:1.0 -f Dockerfile.javaapp .
```

### 2. Kubernetes 배포

```bash
kubectl apply -f deployment.yaml

# Pod 확인
kubectl get pods -l app=java-app-jmx

# 로그 확인
kubectl logs -l app=java-app-jmx -c java-app
kubectl logs -l app=java-app-jmx -c jmx-exporter
```

### 3. 테스트

```bash
# Port forward
kubectl port-forward svc/java-app-jmx 5556:5556

# Prometheus 메트릭 확인
curl http://localhost:5556/metrics | grep simple_java_app

# JMX 메트릭 확인
curl http://localhost:5556/metrics | grep jvm_
```

예상 출력:
```
# HELP simple_java_app_requestcount SimpleJavaApp metric: RequestCount
# TYPE simple_java_app_requestcount gauge
simple_java_app_requestcount 142.0

# HELP simple_java_app_errorcount SimpleJavaApp metric: ErrorCount
# TYPE simple_java_app_errorcount gauge
simple_java_app_errorcount 14.0

# HELP simple_java_app_lastresponsetime SimpleJavaApp metric: LastResponseTime
# TYPE simple_java_app_lastresponsetime gauge
simple_java_app_lastresponsetime 87.0

# HELP jvm_memory_heap_used_bytes JVM heap memory used
# TYPE jvm_memory_heap_used_bytes gauge
jvm_memory_heap_used_bytes 4.5670912E7
```

## ConfigMap 설정

`jmx-config.yaml`은 JMX 메트릭을 Prometheus 형식으로 매핑하는 규칙을 정의합니다:

```yaml
rules:
# 애플리케이션 메트릭
- pattern: 'com.example<type=SimpleJavaApp><>(RequestCount|ErrorCount): (\d+)'
  name: simple_java_app_$1
  type: GAUGE

# JVM 메트릭
- pattern: 'java.lang<type=Memory><HeapMemoryUsage>(\w+): (\d+)'
  name: jvm_memory_heap_$1_bytes
  type: GAUGE
```

## 학습 포인트

1. **레거시 시스템 통합**: 코드 수정 없이 모니터링 시스템 변경
2. **프로토콜 변환**: JMX (RMI) → HTTP (Prometheus)
3. **ConfigMap 활용**: 변환 규칙을 외부화하여 관리
4. **localhost 통신**: 같은 Pod 내 컨테이너 간 네트워크

## 실무 적용

이 패턴은 다음 상황에서 유용합니다:
- Spring Boot 애플리케이션 (Actuator 사용 전)
- Tomcat, JBoss 등 레거시 애플리케이션 서버
- Kafka, Cassandra 등 JMX 기반 시스템

## 정리

```bash
kubectl delete -f deployment.yaml
```
