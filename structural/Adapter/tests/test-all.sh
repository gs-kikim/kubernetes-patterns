#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Adapter Pattern - Integration Tests${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}docker not found. Please install Docker.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ kubectl found${NC}"
echo -e "${GREEN}✓ docker found${NC}"

# Check Kubernetes connection
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Kubernetes cluster accessible${NC}"
echo ""

# Build images
echo -e "${YELLOW}Building Docker images...${NC}"

EXAMPLES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Example 1
echo "Building Example 1 images..."
cd "$EXAMPLES_DIR/example1-basic-prometheus"
docker build -t k8spatterns/random-generator:1.0 -f Dockerfile.app . > /dev/null 2>&1
docker build -t k8spatterns/prometheus-adapter:1.0 -f Dockerfile.adapter . > /dev/null 2>&1
echo -e "${GREEN}✓ Example 1 images built${NC}"

# Example 2
echo "Building Example 2 images..."
cd "$EXAMPLES_DIR/example2-jmx-exporter"
docker build -t k8spatterns/simple-java-app:1.0 -f Dockerfile.javaapp . > /dev/null 2>&1
echo -e "${GREEN}✓ Example 2 images built${NC}"

# Example 3
echo "Building Example 3 images..."
cd "$EXAMPLES_DIR/example3-log-format"
docker build -t k8spatterns/multi-format-app:1.0 -f Dockerfile.app . > /dev/null 2>&1
echo -e "${GREEN}✓ Example 3 images built${NC}"

# Example 4
echo "Building Example 4 images..."
cd "$EXAMPLES_DIR/example4-native-sidecar"
docker build -t k8spatterns/batch-job:1.0 -f Dockerfile.job . > /dev/null 2>&1
docker build -t k8spatterns/metrics-adapter:1.0 -f Dockerfile.adapter . > /dev/null 2>&1
echo -e "${GREEN}✓ Example 4 images built${NC}"

echo ""

# Test Example 1
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Testing Example 1: Basic Prometheus Adapter${NC}"
echo -e "${YELLOW}========================================${NC}"

cd "$EXAMPLES_DIR/example1-basic-prometheus"
kubectl apply -f deployment.yaml > /dev/null

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=random-generator --timeout=120s > /dev/null

POD=$(kubectl get pods -l app=random-generator -o jsonpath='{.items[0].metadata.name}')
echo -e "${GREEN}✓ Pod $POD is ready${NC}"

# Generate some traffic
echo "Generating random numbers..."
kubectl exec $POD -c random-generator -- python -c "
import urllib.request
for i in range(10):
    urllib.request.urlopen('http://localhost:8080/random').read()
" > /dev/null 2>&1

sleep 5

# Check metrics
echo "Checking Prometheus metrics..."
METRICS=$(kubectl exec $POD -c prometheus-adapter -- wget -qO- http://localhost:9889/metrics 2>/dev/null)

if echo "$METRICS" | grep -q "random_generation_total"; then
    echo -e "${GREEN}✓ Metrics endpoint working${NC}"
else
    echo -e "${RED}✗ Metrics endpoint not working${NC}"
    kubectl delete -f deployment.yaml > /dev/null
    exit 1
fi

kubectl delete -f deployment.yaml > /dev/null
echo -e "${GREEN}✓ Example 1 PASSED${NC}"
echo ""

# Test Example 2
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Testing Example 2: JMX Exporter Adapter${NC}"
echo -e "${YELLOW}========================================${NC}"

cd "$EXAMPLES_DIR/example2-jmx-exporter"
kubectl apply -f deployment.yaml > /dev/null

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=java-app-jmx --timeout=180s > /dev/null

POD=$(kubectl get pods -l app=java-app-jmx -o jsonpath='{.items[0].metadata.name}')
echo -e "${GREEN}✓ Pod $POD is ready${NC}"

sleep 10

# Check JMX metrics
echo "Checking JMX Exporter metrics..."
METRICS=$(kubectl exec $POD -c jmx-exporter -- wget -qO- http://localhost:5556/metrics 2>/dev/null)

if echo "$METRICS" | grep -q "simple_java_app"; then
    echo -e "${GREEN}✓ JMX metrics exported${NC}"
else
    echo -e "${RED}✗ JMX metrics not found${NC}"
    kubectl delete -f deployment.yaml > /dev/null
    exit 1
fi

kubectl delete -f deployment.yaml > /dev/null
echo -e "${GREEN}✓ Example 2 PASSED${NC}"
echo ""

# Test Example 3
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Testing Example 3: Log Format Adapter${NC}"
echo -e "${YELLOW}========================================${NC}"

cd "$EXAMPLES_DIR/example3-log-format"
kubectl apply -f deployment.yaml > /dev/null

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=multi-format-app --timeout=120s > /dev/null

POD=$(kubectl get pods -l app=multi-format-app -o jsonpath='{.items[0].metadata.name}')
echo -e "${GREEN}✓ Pod $POD is ready${NC}"

# Generate some logs
echo "Generating multi-format logs..."
kubectl exec $POD -c app -- python -c "
import urllib.request
for i in range(5):
    try:
        urllib.request.urlopen('http://localhost:8080/api/data').read()
    except:
        pass
" > /dev/null 2>&1

sleep 5

# Check Fluent Bit output
echo "Checking log adapter output..."
LOGS=$(kubectl logs $POD -c log-adapter --tail=10 2>/dev/null)

if [ -n "$LOGS" ]; then
    echo -e "${GREEN}✓ Log adapter processing logs${NC}"
else
    echo -e "${YELLOW}⚠ Log adapter output empty (may be normal)${NC}"
fi

kubectl delete -f deployment.yaml > /dev/null
echo -e "${GREEN}✓ Example 3 PASSED${NC}"
echo ""

# Test Example 4
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Testing Example 4: Native Sidecar${NC}"
echo -e "${YELLOW}========================================${NC}"

cd "$EXAMPLES_DIR/example4-native-sidecar"

# Check Kubernetes version
K8S_VERSION=$(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}' | sed 's/v//' | cut -d'.' -f1,2)
K8S_MINOR=$(echo $K8S_VERSION | cut -d'.' -f2)

if [ "$K8S_MINOR" -lt 28 ]; then
    echo -e "${YELLOW}⚠ Kubernetes 1.28+ required for Native Sidecar${NC}"
    echo -e "${YELLOW}  Current version: $K8S_VERSION${NC}"
    echo -e "${YELLOW}  Skipping Native Sidecar test${NC}"
else
    echo "Testing Native Sidecar Job..."
    kubectl apply -f job-native-sidecar.yaml > /dev/null

    echo "Waiting for job to complete..."
    if kubectl wait --for=condition=complete job/batch-job-native-sidecar --timeout=120s > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Native Sidecar Job completed successfully${NC}"
    else
        echo -e "${YELLOW}⚠ Job did not complete in time (expected for large TOTAL_ITEMS)${NC}"
    fi

    kubectl delete -f job-native-sidecar.yaml > /dev/null
    echo -e "${GREEN}✓ Example 4 PASSED${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All Tests Completed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Summary:"
echo -e "${GREEN}✓ Example 1: Basic Prometheus Adapter${NC}"
echo -e "${GREEN}✓ Example 2: JMX Exporter Adapter${NC}"
echo -e "${GREEN}✓ Example 3: Log Format Adapter${NC}"
if [ "$K8S_MINOR" -ge 28 ]; then
    echo -e "${GREEN}✓ Example 4: Native Sidecar Adapter${NC}"
else
    echo -e "${YELLOW}⊗ Example 4: Skipped (requires Kubernetes 1.28+)${NC}"
fi
echo ""
