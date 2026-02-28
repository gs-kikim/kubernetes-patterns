# Example 3: Log Format Adapter

## 개요

다양한 형식의 로그를 표준 JSON 형식으로 변환하는 Adapter Pattern 예제입니다.

**실무 시나리오**:
- 레거시 애플리케이션이 여러 로그 형식을 혼용
- 중앙 로깅 시스템 (ELK, Loki)에 통합 필요
- 애플리케이션 코드 수정 없이 로그 형식 표준화

## 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                         Pod                             │
│  ┌─────────────────┐    ┌─────────────────────────┐    │
│  │ Application     │    │ Fluent Bit              │    │
│  │                 │    │ Adapter                 │    │
│  │ Mixed Format   │───▶│                         │───▶│ Logging
│  │ Logs:          │    │ JSON Output             │    │ System
│  │ - Apache       │    │                         │    │
│  │ - Custom       │    │                         │    │
│  │ - Syslog       │    │                         │    │
│  │ - CSV          │    │                         │    │
│  └─────────────────┘    └─────────────────────────┘    │
│         │                        ▲                      │
│         └────────────────────────┘                      │
│           emptyDir (logs)                               │
└─────────────────────────────────────────────────────────┘
```

## 지원 로그 형식

### 1. Apache Common Log Format
```
127.0.0.1 - - [15/Jan/2024:10:30:45 +0000] "GET /api/data HTTP/1.1" 200 2326
```

### 2. Custom Application Format
```
[2024-01-15 10:30:45] INFO: Request processed | status=200 | duration=45ms
```

### 3. Syslog-like Format
```
Jan 15 10:30:45 localhost app[12345]: Request status=200 duration=45ms
```

### 4. CSV Format
```
2024-01-15T10:30:45,INFO,200,45.23
```

## 변환 결과 (JSON)

모든 형식이 다음과 같은 통일된 JSON으로 변환됩니다:

```json
{
  "time": "2024-01-15T10:30:45Z",
  "level": "INFO",
  "status": 200,
  "duration": 45.23,
  "app_name": "multi-format-app",
  "environment": "production"
}
```

## 배포 방법

### 1. 이미지 빌드

```bash
docker build -t k8spatterns/multi-format-app:1.0 -f Dockerfile.app .
```

### 2. Kubernetes 배포

```bash
kubectl apply -f deployment.yaml

# Pod 확인
kubectl get pods -l app=multi-format-app

# 로그 확인
kubectl logs -l app=multi-format-app -c app
kubectl logs -l app=multi-format-app -c log-adapter
```

### 3. 테스트

```bash
# Port forward
kubectl port-forward svc/multi-format-app 8080:80

# Generate logs in various formats
for i in {1..20}; do
  curl http://localhost:8080/api/data
  sleep 1
done

# Check Fluent Bit output (standardized JSON)
kubectl logs -l app=multi-format-app -c log-adapter --tail=20
```

예상 출력 (Fluent Bit):
```json
{"date":1705315845.0,"time":"2024-01-15T10:30:45Z","level":"INFO","status":200,"duration":45.23,"app_name":"multi-format-app","environment":"production"}
{"date":1705315846.0,"time":"2024-01-15T10:30:46Z","level":"ERROR","status":500,"duration":12.45,"app_name":"multi-format-app","environment":"production"}
```

## Fluent Bit Configuration

### Input
```conf
[INPUT]
    Name              tail
    Path              /var/log/app/application.log
    Tag               app.logs
```

### Parsers
```conf
[PARSER]
    Name        apache
    Format      regex
    Regex       ^(?<host>[^ ]*) ... (?<status>[^ ]*)$

[PARSER]
    Name        custom
    Format      regex
    Regex       ^\[(?<time>[^\]]+)\] (?<level>\w+): ...
```

### Filter & Output
```conf
[FILTER]
    Name          modify
    Match         app.logs
    Add           app_name multi-format-app

[OUTPUT]
    Name          stdout
    Match         app.logs
    Format        json_lines
```

## 실무 확장

### ELK Stack 통합
```yaml
[OUTPUT]
    Name          es
    Match         app.logs
    Host          elasticsearch
    Port          9200
    Index         app-logs
    Type          _doc
```

### Loki 통합
```yaml
[OUTPUT]
    Name          loki
    Match         app.logs
    Host          loki
    Port          3100
    Labels        app=multi-format-app
```

## 학습 포인트

1. **로그 표준화**: 다양한 형식을 하나의 형식으로 통합
2. **Fluent Bit 활용**: 경량 로그 프로세서로 Adapter 구현
3. **정규표현식**: 복잡한 로그 패턴 파싱
4. **ConfigMap**: 파싱 규칙을 외부화하여 관리

## 정리

```bash
kubectl delete -f deployment.yaml
```
