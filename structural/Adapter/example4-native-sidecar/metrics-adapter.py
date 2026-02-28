#!/usr/bin/env python3
"""
Metrics Adapter - Native Sidecar
Converts JSON metrics to Prometheus format
Demonstrates proper startup/shutdown with Native Sidecar
"""
import json
import os
import time
from prometheus_client import start_http_server, Gauge
from prometheus_client.core import REGISTRY, GaugeMetricFamily

METRICS_FILE = os.environ.get('METRICS_FILE', '/data/metrics.json')
METRICS_PORT = int(os.environ.get('METRICS_PORT', 9889))

# Prometheus metrics
job_processed = Gauge('batch_job_items_processed', 'Total items processed')
job_successful = Gauge('batch_job_items_successful', 'Successfully processed items')
job_failed = Gauge('batch_job_items_failed', 'Failed items')
job_success_rate = Gauge('batch_job_success_rate', 'Success rate percentage')
job_processing_time = Gauge('batch_job_processing_time_seconds', 'Total processing time')

def read_metrics():
    """Read and parse metrics file"""
    if not os.path.exists(METRICS_FILE):
        print(f"Metrics file not found: {METRICS_FILE}")
        return None

    try:
        with open(METRICS_FILE, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error reading metrics: {e}")
        return None

def update_prometheus_metrics():
    """Update Prometheus metrics from JSON file"""
    metrics = read_metrics()

    if not metrics:
        return

    try:
        job_processed.set(metrics.get('processed', 0))
        job_successful.set(metrics.get('successful', 0))
        job_failed.set(metrics.get('failed', 0))
        job_success_rate.set(metrics.get('success_rate', 0))

        total_time_ms = metrics.get('total_processing_time_ms', 0)
        job_processing_time.set(total_time_ms / 1000.0)

        print(f"Metrics updated: processed={metrics.get('processed', 0)}, "
              f"success_rate={metrics.get('success_rate', 0):.2f}%")

    except Exception as e:
        print(f"Error updating metrics: {e}")

def main():
    print(f"Native Sidecar Metrics Adapter started")
    print(f"Metrics file: {METRICS_FILE}")
    print(f"Prometheus endpoint: http://localhost:{METRICS_PORT}/metrics")

    # Start Prometheus HTTP server
    start_http_server(METRICS_PORT)

    # Wait for metrics file to be created
    wait_count = 0
    while not os.path.exists(METRICS_FILE) and wait_count < 30:
        print(f"Waiting for metrics file... ({wait_count}s)")
        time.sleep(1)
        wait_count += 1

    if not os.path.exists(METRICS_FILE):
        print("Warning: Metrics file not found after 30s, continuing anyway")

    print("Adapter ready, monitoring metrics file")

    # Monitor and update metrics
    last_mtime = 0

    try:
        while True:
            if os.path.exists(METRICS_FILE):
                mtime = os.path.getmtime(METRICS_FILE)

                # Update if file was modified
                if mtime != last_mtime:
                    update_prometheus_metrics()
                    last_mtime = mtime

            time.sleep(2)

    except KeyboardInterrupt:
        print("\nAdapter shutting down gracefully")
    except Exception as e:
        print(f"Adapter error: {e}")

if __name__ == '__main__':
    main()
