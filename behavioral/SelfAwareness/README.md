# Self Awareness Pattern - Test Examples

This directory contains test examples for the **Self Awareness** behavioral pattern from Kubernetes Patterns.

## Prerequisites

- **minikube** installed and running
- **kubectl** configured to use minikube context

```bash
# Start minikube if not running
minikube start

# Verify connection
kubectl cluster-info
```

## Quick Start

Run all tests automatically:

```bash
# Make the script executable (if not already)
chmod +x test.sh

# Run all tests
./test.sh
```

The test script will:
1. Check minikube status and start if needed
2. Clean up any existing test pods
3. Run all 5 test scenarios sequentially
4. Display results and logs
5. Provide cleanup instructions

## Pattern Overview

The Self Awareness pattern uses Kubernetes Downward API to expose Pod and container metadata to applications without requiring direct API server access. This enables:

- Non-intrusive metadata access (no Kubernetes client libraries needed)
- Platform-independent approach (works with any language)
- Reduced API server load
- Dynamic runtime information injection

## Important Notes on Downward API Limitations

**Volume vs Environment Variable support:**
- `status.podIP` and `spec.nodeName` can **only** be accessed via **environment variables**
- They **cannot** be mounted as volume files
- Volumes support: `metadata.name`, `metadata.namespace`, `metadata.uid`, `metadata.labels`, `metadata.annotations`

## Test Scenarios

### 1. Environment Variable Injection (`01-env-variables.yaml`)

Demonstrates how to inject Pod metadata and resource limits as environment variables.

**Features tested:**
- Pod metadata (name, namespace, IP, UID)
- Node information (node name, host IP)
- Labels and annotations
- Resource limits and requests (CPU, memory)

**Test commands:**
```bash
# Create the Pod
kubectl apply -f 01-env-variables.yaml

# Wait for Pod to be ready
kubectl wait --for=condition=Ready pod/env-downward-demo --timeout=60s

# View the output
kubectl logs env-downward-demo

# Verify specific environment variables
kubectl exec env-downward-demo -- env | grep MY_POD_NAME
kubectl exec env-downward-demo -- env | grep MEMORY_LIMIT_MB

# Cleanup
kubectl delete -f 01-env-variables.yaml
```

**Expected output:**
```
=== Self Awareness Pattern - Environment Variables ===

Pod Information:
  Pod Name: env-downward-demo
  Namespace: default
  Pod IP: 10.244.x.x
  Node Name: <node-name>
  Service Account: default
  Pod UID: <unique-id>

Resource Information:
  Memory Limit: 256 MB
  CPU Limit: 200 milliCPU
  Memory Request: 128 MB
  CPU Request: 100 milliCPU

Labels:
  App Version: 1.0
  Tier: backend
```

### 2. Volume-based Metadata Injection (`02-volume-metadata.yaml`)

Demonstrates mounting Pod metadata and resource information as files.

**Features tested:**
- All labels as a file
- All annotations as a file
- Individual metadata fields as separate files
- Resource limits as files

**Test commands:**
```bash
# Create the Pod
kubectl apply -f 02-volume-metadata.yaml

# Wait for Pod to be ready
kubectl wait --for=condition=Ready pod/volume-downward-demo --timeout=60s

# View the output
kubectl logs volume-downward-demo

# Examine mounted files
kubectl exec volume-downward-demo -- ls -la /etc/podinfo
kubectl exec volume-downward-demo -- cat /etc/podinfo/labels
kubectl exec volume-downward-demo -- cat /etc/podinfo/annotations
kubectl exec volume-downward-demo -- cat /etc/resources/mem_limit

# Cleanup
kubectl delete -f 02-volume-metadata.yaml
```

**Expected output:**
```
=== Self Awareness Pattern - Volume-based Metadata ===

=== All Labels ===
app="random-generator"
environment="test"
pattern="self-awareness"
version="2.0"

=== All Annotations ===
build-id="build-456"
description="Self Awareness pattern - Volume-based metadata injection"
team="platform-team"
```

### 3. Dynamic Label/Annotation Updates (`03-dynamic-update.yaml`)

Demonstrates that volume-mounted labels and annotations are updated dynamically when changed.

**Features tested:**
- Real-time label update detection
- Real-time annotation update detection
- File change monitoring with MD5 checksums

**Test commands:**
```bash
# Terminal 1: Create Pod and watch logs
kubectl apply -f 03-dynamic-update.yaml
kubectl logs -f dynamic-update-demo

# Terminal 2: Update labels and annotations
# Wait a few seconds after Pod creation, then run:
kubectl label pod dynamic-update-demo stage=beta --overwrite
sleep 10

kubectl label pod dynamic-update-demo feature=new-api
sleep 10

kubectl annotate pod dynamic-update-demo config-version=v2 --overwrite
sleep 10

kubectl annotate pod dynamic-update-demo updated-at="$(date)" --overwrite

# Watch Terminal 1 for change notifications (updates appear within 60-120 seconds)

# Cleanup
kubectl delete -f 03-dynamic-update.yaml
```

**Expected behavior:**
- Initial state displayed
- After label/annotation changes, updates detected within 1-2 minutes
- Timestamp and new values shown

**Note:** Kubernetes updates volume-mounted metadata with eventual consistency. Changes may take 60-120 seconds to appear.

### 4. Resource-Aware Application (`04-resource-aware-app.yaml`)

Demonstrates auto-tuning application settings based on resource limits.

**Features tested:**
- Worker thread calculation based on CPU limits
- Cache size calculation based on memory limits
- Connection pool sizing
- Multiple Pods with different resource configurations

**Test commands:**
```bash
# Create both Pods (small and large)
kubectl apply -f 04-resource-aware-app.yaml

# Wait for Pods
kubectl wait --for=condition=Ready pod/resource-aware-app --timeout=60s
kubectl wait --for=condition=Ready pod/resource-aware-app-large --timeout=60s

# Compare small vs large configuration
echo "=== Small Configuration ==="
kubectl logs resource-aware-app

echo "=== Large Configuration ==="
kubectl logs resource-aware-app-large

# Observe different calculated settings based on resources

# Cleanup
kubectl delete -f 04-resource-aware-app.yaml
```

**Expected output:**
Small configuration should show:
- Worker Threads: 1 (500m CPU / 1000)
- Cache Size: 128 MB (25% of 512MB)
- Connection Pool: ~16

Large configuration should show:
- Worker Threads: 2 (2000m CPU / 1000)
- Cache Size: 512 MB (25% of 2048MB)
- Connection Pool: 64

### 5. Multi-Container Pod (`05-multi-container.yaml`)

Demonstrates metadata sharing across multiple containers in a Pod.

**Features tested:**
- Init container accessing main container resources
- Sidecar container monitoring main container
- Shared volume for Pod-level information
- Per-container resource information
- Dynamic nginx configuration based on CPU limits

**Test commands:**
```bash
# Create the multi-container Pod
kubectl apply -f 05-multi-container.yaml

# Wait for Pod to be ready
kubectl wait --for=condition=Ready pod/multi-container-aware --timeout=90s

# Check init container logs (config generation)
kubectl logs multi-container-aware -c config-generator

# Check monitor sidecar logs
kubectl logs multi-container-aware -c monitor

# Verify nginx is running with generated config
kubectl logs multi-container-aware -c main-app

# Test the /info endpoint (if using port-forward)
kubectl port-forward pod/multi-container-aware 8080:80 &
curl http://localhost:8080/info

# Cleanup
kubectl delete -f 05-multi-container.yaml
```

**Expected output:**
```
=== Monitoring Sidecar Started ===

Pod Information:
  Pod Name: multi-container-aware
  Namespace: default
  Node: <node-name>

Main Application Resources:
  Memory Limit: 1024 MB
  CPU Limit: 1000 milliCPU

Monitor Sidecar Resources:
  Memory Limit: 128 MB
  CPU Limit: 100 milliCPU

Total Pod Resources:
  Total Memory: 1152 MB
  Total CPU: 1100 milliCPU
```

## Running All Tests

You can run all tests sequentially:

```bash
# Run all tests
for file in 01-env-variables.yaml 02-volume-metadata.yaml 04-resource-aware-app.yaml 05-multi-container.yaml; do
  echo "Testing $file..."
  kubectl apply -f $file
  sleep 5
done

# View all Pod logs
kubectl get pods | grep -E 'env-downward|volume-downward|resource-aware|multi-container' | awk '{print $1}' | xargs -I {} kubectl logs {}

# Cleanup
kubectl delete -f 01-env-variables.yaml
kubectl delete -f 02-volume-metadata.yaml
kubectl delete -f 04-resource-aware-app.yaml
kubectl delete -f 05-multi-container.yaml
```

## Key Learning Points

### 1. **Environment Variables vs Volumes**

| Aspect | Environment Variables | Volumes |
|--------|----------------------|---------|
| Update behavior | Static (set at Pod start) | Dynamic (updated at runtime) |
| Use case | Startup configuration | Runtime-updatable metadata |
| Complexity | Simple | More complex |
| Best for | Resource limits, Pod ID | Labels, annotations |

### 2. **Available Downward API Fields**

**Pod-level (fieldRef):**
- `metadata.name` - Pod name
- `metadata.namespace` - Namespace
- `metadata.uid` - Unique Pod ID
- `metadata.labels['<KEY>']` - Specific label
- `metadata.annotations['<KEY>']` - Specific annotation
- `spec.nodeName` - Node name
- `spec.serviceAccountName` - Service account
- `status.podIP` - Pod IP address
- `status.hostIP` - Node IP address

**Container-level (resourceFieldRef):**
- `requests.cpu` - CPU request
- `limits.cpu` - CPU limit
- `requests.memory` - Memory request
- `limits.memory` - Memory limit
- `requests.ephemeral-storage` - Storage request
- `limits.ephemeral-storage` - Storage limit

### 3. **Common Divisors**

For resource fields, use divisors to convert units:
- `1m` - millicores (1/1000 of a CPU)
- `1Ki` - Kibibytes (1024 bytes)
- `1Mi` - Mebibytes (1024 * 1024 bytes)
- `1Gi` - Gibibytes (1024^3 bytes)

### 4. **Real-world Use Cases**

- **Structured Logging**: Include Pod name, namespace in logs
- **Monitoring**: Tag metrics with Pod metadata
- **Auto-tuning**: Adjust thread pools, cache sizes based on resources
- **Service Discovery**: Build cluster member lists
- **Multi-tenancy**: Extract namespace for tenant isolation

## Troubleshooting

### Environment variable is empty
```bash
# Check the fieldPath in Pod spec
kubectl get pod <pod-name> -o yaml | grep -A 5 "env:"

# Verify the field exists
kubectl get pod <pod-name> -o jsonpath='{.metadata.name}'
```

### Volume files not updating
- Updates can take 60-120 seconds (kubelet sync period)
- Only labels and annotations update dynamically
- Other fields (like podIP) remain static

### Wrong resource values
```bash
# Check divisor in resourceFieldRef
kubectl get pod <pod-name> -o yaml | grep -A 10 "resourceFieldRef"

# Verify actual resource limits
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[0].resources}'
```

## Related Patterns

- **Init Container**: Use Self Awareness in init containers for setup
- **Sidecar**: Share Pod metadata between main and sidecar containers
- **Configuration Resource**: Combine ConfigMap with Downward API

## References

- [Blog Post (Korean)](../../files/chapter14_self_awareness_blog_ko.md)
- [Kubernetes Downward API Documentation](https://kubernetes.io/docs/concepts/workloads/pods/downward-api/)
- [K8s Patterns Examples](https://github.com/k8spatterns/examples/tree/main/behavioral/SelfAwareness)
