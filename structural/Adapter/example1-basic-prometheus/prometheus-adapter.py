#!/usr/bin/env python3
"""
Prometheus Adapter - Converts custom log format to Prometheus metrics
Reads the random generator log file and exposes metrics in Prometheus format
"""
import json
import os
import time
from prometheus_client import start_http_server, Gauge, Counter, Histogram

LOG_FILE = os.environ.get('LOG_FILE', '/var/log/random.log')
METRICS_PORT = int(os.environ.get('METRICS_PORT', 9889))

# Define Prometheus metrics
generation_duration = Histogram(
    'random_generation_duration_seconds',
    'Time spent generating random numbers',
    buckets=[0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 1.0]
)

generation_total = Counter(
    'random_generation_total',
    'Total number of random number generations'
)

last_generated_value = Gauge(
    'random_last_generated_value',
    'The last generated random value'
)

adapter_errors_total = Counter(
    'adapter_errors_total',
    'Total number of adapter parsing errors'
)

def parse_log_file():
    """Parse log file and update Prometheus metrics"""
    if not os.path.exists(LOG_FILE):
        print(f"Log file does not exist yet: {LOG_FILE}")
        return

    position_file = '/tmp/log_position'
    last_position = 0

    # Read last processed position
    if os.path.exists(position_file):
        try:
            with open(position_file, 'r') as f:
                last_position = int(f.read().strip() or 0)
        except Exception as e:
            print(f"Error reading position file: {e}")

    try:
        with open(LOG_FILE, 'r') as f:
            f.seek(last_position)

            for line in f:
                line = line.strip()
                if not line:
                    continue

                try:
                    entry = json.loads(line)

                    # Update metrics
                    duration_sec = entry['duration_ms'] / 1000.0
                    generation_duration.observe(duration_sec)
                    generation_total.inc()
                    last_generated_value.set(entry['value'])

                except (json.JSONDecodeError, KeyError) as e:
                    print(f"Error parsing log entry: {e}")
                    adapter_errors_total.inc()

            # Save current position
            current_position = f.tell()
            with open(position_file, 'w') as pf:
                pf.write(str(current_position))

    except Exception as e:
        print(f"Error processing log file: {e}")
        adapter_errors_total.inc()

def main():
    # Start Prometheus HTTP server
    start_http_server(METRICS_PORT)
    print(f"Prometheus Adapter started on port {METRICS_PORT}")
    print(f"Reading from: {LOG_FILE}")
    print(f"Metrics endpoint: http://localhost:{METRICS_PORT}/metrics")

    # Periodically parse log file
    while True:
        parse_log_file()
        time.sleep(5)  # Update every 5 seconds

if __name__ == '__main__':
    main()
